##################################################
##################################################
##						##
## Devel::GDB - open and manipulate gdb process	##
##						##
##	Josef Ezra     				##
##	EMC                                     ##
##	jezra@emc.com           		##
##	jezra@newmail.net			##
##						##
##################################################
##################################################


=head1 NAME

    Devel::GDB - open and communicate a gdb session

=head1 SYNOPSIS

    use Devel::GDB ;

    $gdb = new Devel::GDB (-file => 'a.out' ) ;

    $gdb -> get ( 'break main' ) ; 

=head1	DESCRIPTION 

Devel::GDB is an Expect like module, designed to communicate with
gdb. It is opening a gdb process, sending commands and returning 
the responses. Devel::GDB was designed to provide good base for 
both interactive and automatic scripts.

=over 2

=head2 Example Code

=over 4

use Devel::GDB ; 

our $gdb = new Devel::GDB (-execfile => 'gdb') ; 

my $arch   = $gdb -> get ( 'info arch'  ) ; 

my $endian = $gdb -> get ( 'show endian' ) ;

print $arch, $endian ;

=back

=back

=head1 METHODS

The three methods for normal gdb usage are: 'new', 'get' and 'signal'. 

=over 4

=head2 new

=item $gdb = Devel::GDB -> new (?options?)

This function opens and initializes the gdb object.

B<Options:>

=over 2

=item -file 

File to open (like 'a.out'). No default. This is an easy way to load 
target file during initialization.

=item -execfile

File or command to execute as gdb process. Default is 'gdb'. 

=item -params

Parameters to the 'execfile'. Default is " -q -nx -nw ".
Parameters can be also set as part of the 'execfile' string. 

=item -timeout 

Default timeout for B<get> method. Default is 9999 ; 

=item -prompt

Default prompt for B<get> method (to identify end of gdb response). 
Default is qr/\(s?gdb.*\)|^\s*\>|(y or n)/s.

=item -notyet

Default code to be used at the B<get> method while waiting for gdb response. 

=item -alldone

Default code to be used at the B<get> method after waiting for gdb response. 

=back 

The (actually internal) method B<new_shell> can be used to open and manipulate
 any kind of flushing && prompting process. Unlike B<new>, it would not set
 defaults or run initial commands.

=head2 get

=item $gdb -> get ( ?command?, ?timeout?, ?prompt?, ?notyet?, ?alldone? )

Send command to gdb and return response. 
In array contest, return response, error, and matching prompt. 
In scalar contest, return response only ('' if error). 

B<Parameters:> 

=over 2

=item command

Command to be sent to gdb. If undef or white-spaces, gdb buffers will be cleared
 and returned (timeouted old responses?). 

=item timeout 

Limit the waiting time for gdb (integer seconds). If timeout expires, get returns 
without interrupting the gdb process (use B<signal> for that). 
The default timeout (9999) can be overwritten in B<new>.

=item prompt 

Expected regexpr prompt at the end of gdb response. 
The default prompt (qr/\(s?gdb.*\)|^\s*\>|(y or n)/s) can be overwritten in B<new>.

=item notyet

Code to be executed every second while waiting for response. Only valid code will be
 executed (i.e. ref $code eq 'CODE'). If this code returns true, B<get> would stop 
waiting to gdb response. Then B<signal> can be used to interrupt gdb process.
Default notyet code can be set in B<new>.

=item alldone

Code to be executed when done. Only valid code will be executed. 
Default alldone code can be set in B<new>. 

=back 

=head2 signal

=item $gdb -> signal(?signum?)

Send a signal to the gdb process. Default signum is 0 (functions as
Control-c in gdb command prompt)

=back

=head1 AUTHOR

Josef Ezra E<lt>jezra@emc.comE<gt>

=head1 SEE ALSO

B<IPC::Open3>

=cut



package Devel::GDB ; 

use strict ;
# use warnings ;

use 5.004 ;
use integer ;

use FileHandle ;
use IPC::Open3 ;

use vars qw/$VERSION/; 

$VERSION = 1.22 ; 

sub new { 
#  ------------------------------------------------------------------
#  call new_shell and proper initializes  gdb. 
#  ------------------------------------------------------------------

    my $class = shift or 
        die "Internal: Hey! this is a structured module, do not mess it" ;

    my %sgdb = map /^-?(.*)$/o, map $_ || '', @_ ;

    $sgdb{'execfile' } ||= 'gdb' ; 
    $sgdb{'params'   } ||= " -q -nx -nw " ;
    $sgdb{'timeout'  } ||=  9999 ; 
    $sgdb{'prompt'   } ||= eval {qr/\(s?gdb.*\)|^\s*\>|(y or n)/s} || '/\(s?gdb.*\)|^\s*\>|(y or n)' ;
                          # is this perl version support qr//  ? 

    my $s = $class -> new_shell (%sgdb) ;

    my ($buf, $err, @buffers, @errors) ;

    $_ = $s -> get ()  ; 

    my @initial_cmds = ("set confirm off",
                        "set height 0",
                        "set width 0",
                        "set print pretty on") ;

    my $cmd ;

    foreach $cmd (@initial_cmds) {
        ($buf, $err)  = $s -> get ($cmd) ;
        push @buffers, $buf if $buf =~ /\w/ ;
        die "sgdb returned $err in 'set' command (is it really running?)\n" if $err ;
        # if error during those commands then something must be wrong
    }

    ($buf, $err)  = $s -> get ("file " . $s->{ 'file' }, 100) if $s -> { 'file' } ;
    push @buffers, $buf if $buf ;
    $buf = $s -> get () ;     # clear
    push @buffers, $buf if $buf ;
    push @errors, "Error: $err during file command" if $err ;

    return ($s, join ("\n", @buffers) , join ("\n", @errors)) if wantarray ;
    return  $s ;
}

sub new_shell {

#  ------------------------------------------------------------------
#  this function returns object associated with a piped system command.
#  ------------------------------------------------------------------

    my $class = shift or 
        die "Internal: Hey! this is a structured module, do not mess it" ;

    $class = ref $class if ref $class ;

    my %sgdb = map /^-?(.*)$/o, @_ ;

    die "Internal: no command name" unless exists $sgdb{ 'execfile' } ;

                                            # initial the command
    my $gdbcmd = join ' ', @sgdb{ 'execfile', 'params' } ;

#    my ($IN, $OUT, $ERR) = (new FileHandle, new FileHandle, new FileHandle) ;

    # on second thought, I prefer errors to be displayed as normal response
    # should I allow the former by switch? 
    my ($IN, $OUT, $ERR) = ( new FileHandle, (new FileHandle) x 2) ;

    $sgdb{'PID'} = open3($IN, $OUT, $ERR, $gdbcmd) or die "new: open3 cannot fork\n" ;

    @sgdb{'IN', 'OUT', 'ERR'} = ($IN, $OUT, $ERR) ;

    bless \%sgdb, $class ;
}

sub get { 

#  ------------------------------------------------------------------
#  this function send command and return response for Devel::GDB object
#  ------------------------------------------------------------------

    # get params:
    #      self                      : this (initialized) object 
    #      command  |''              : if !/\S/ just get_stream (clear buffer)
    #      timeout  |$self->{timeout}: wait limit (integer seconds), 
    #      expect_re|$self->{prompt} : wait for this re, 
    #      wait_sub |$self->{notyet} : sub executed every second while waiting
    #      done_sub |$self->{alldone}: sub executed when finished
    # 

    my $self = shift or die "Internal: Hey! this is a structured module, do not mess it" ;

    my $cmd  = shift || '' ;
                                            # single newline at the end
    $cmd =~ s/ \s*$/ \n/ or $cmd =~ s/\s*$/\n/; 

    my ($IN, $OUT, $ERR, $PID) = @{$self}{ qw/IN OUT ERR PID/ } ;

    # TODO semaphore?
    # how about $self -> {semaphore}( up ) if $self->{semaphore} ?

    if ($cmd !~ /\S/) {                     # let empty command be 'clean buffers'

        return (scalar (get_stream($OUT, 0.01, 10_000)), 
                scalar (get_stream($ERR, 0.01, 10_000)),
                "(clear) " ) if wantarray ;
        return (scalar (get_stream($OUT, 0.01, 10_000)) .
                scalar (get_stream($ERR, 0.01, 10_000)) ) ;
                
    }
    if ( my $leftover = get_stream( $OUT, 0.01, 10_000) and $ENV{ 'SGDBTK_DEBUG' } ) {

        print STDERR 'leftover: ',$leftover, "\n" if length $leftover > 10 ;
    }
    # first, send the command (gdb might start working by contest switch!) 
    print $IN $cmd  ;

    # now, plenty of time to play with parameters

    my $timeout = shift || $self->{'timeout'} ;
    $timeout -= time if $timeout++ > 600_000_000 ;

    my $prompt  = shift || $self->{'prompt'} ;

    my $notyet  = shift || $self->{'notyet'} ;
    $notyet = undef unless ref $notyet eq 'CODE' ;

    my $done    = shift || $self->{'alldone'} ;
    $done   = undef unless ref $done   eq 'CODE' ;

    my ($buffer, $rmask, $nread, $buf, $err, $nfound, $rprompt)  = ('') ; 
                                            # now get the respond
  GETTING: while ( !$err ) {

        while (--$timeout >= 1 ) {

            $rmask = "" ;
            vec($rmask, fileno( $OUT ), 1) = 1;
            ($nfound)  = select($rmask, undef, undef, 1) ;
            $nfound and last ;

            if ( $notyet and $notyet->($timeout) ) { 
                $err = 'STOPPED' ;
                last ;
            }
        }

        if (!$nfound) {
            $err ||= 'TIMEOUT' ;
            kill 0 => $PID ;
            last ;
        }

        $nread = sysread( $OUT, $buf, 10_000) ;

        if ($nread <= 0) {
            $err ||= 'EOF' ;
            last ;
        }

        $buffer .= $buf ;

        if ($buffer =~ s/($prompt)\s*$// ) { 
            $rprompt = $1 ;
            last GETTING ;
        }
    }

    $done and $done->() ;

    return ( $buffer , 
            ($err || '') ,
            ($rprompt || '')) if wantarray() ;

    $self->{'last_error'} = $err ;
    return $buffer ;
}

sub get_stream {
    
    # ----------------------------------------------------------------
    # get_stream: select and read limited available bytes from stream 
    # ----------------------------------------------------------------

    no integer ;
    my $stream   = shift or die "Internal: no stream parameter";
    ref $stream and ref ($stream) ne 'FileHandle' and  $stream = $stream->{'OUT'} ;
    my $timeout  = shift || 0.1 ;
    my $size     = shift || 10_000 ;

    my ($rmask, $buf, $err) = "" ;

    vec($rmask, fileno( $stream ), 1) = 1;

    if (select $rmask, undef, undef, $timeout) {

        if (! sysread $stream, $buf, $size) {
            $err = "EOF" ;
        }
    }
    else {
        $err = "TIMEOUT" ;
    }

    return ($buf || '', $err) if wantarray ; 
    
    return $buf || '' ;
}

sub clear_stream {
    # ----------------------------------------------------------------
    # just read stream in a loop until timeout
    # ----------------------------------------------------------------

    my $stream = shift or die "Internal: no stream parameter" ;
    my $loops  = shift || 100 ;
    my ($buffer, $buf, $err) = '' ;

    while ($loops-- && !$err ) {

        ($buf, $err) = get_stream( $stream ) ;
        $buffer .= $buf ;
    }

    return ($buffer, $err) if wantarray ;

    return $buffer ;
}

sub get_errstream {
    
    # ----------------------------------------------------------------
    # get_errstream: same us get_stream, but it $stream is a 
    # class, read error stream
    # ----------------------------------------------------------------

    my $stream   = shift or die "Internal: no stream parameter";
    ref $stream and ref ($stream) ne 'FileHandle' and  $stream = $stream->{'ERR'} ;
    get_stream( $stream, 0.01, 10_000) ;
}

sub put_stream {
    
    # ----------------------------------------------------------------
    # put_stream: simple, print to stream. 
    # ----------------------------------------------------------------

    my $stream = shift or die "Internal: no stream parameter" ;
    ref $stream and 'FileHandle' ne ref ($stream) and $stream = $stream->{'IN'} ;
    print $stream @_ ;
}

sub signal {

    # ----------------------------------------------------------------
    # signal: sends signal to process id, or to process related with an object
    # return value of kill
    # ----------------------------------------------------------------

    my $pid = shift ;
    ref $pid and $pid = $pid->{'PID'} ;
    my $sig  = shift || 0 ;
    kill $sig => $pid ;
}

sub destroy {
    
    my $self = shift or return ;

    my $pid = $self->{ 'PID' } ;
    
    kill ( 0, $pid ) and kill ( 9, $pid ) ;

    # Note: kill 0 normally does nothing (well, checks if pid is alive). 
    # gdb use 'SIGHUP' (0) for quitting. both cases, the upper line
    # should work.

    # Perlon: Shall I use -9 to kill all group or should I trust gdb to handle 
    # it's subprocesses by itself? 

    my $IN = $self -> { 'IN' } ;

    close $IN if ref $IN eq 'FileHandle' ;
    
    # Note: the next lines where taken from gdb code: 
    
#  static void
#  init_signals ()
#  {
#    signal (SIGINT, request_quit);

#    /* If SIGTRAP was set to SIG_IGN, then the SIG_IGN will get passed
#       to the inferior and breakpoints will be ignored.  */
#  #ifdef SIGTRAP
#    signal (SIGTRAP, SIG_DFL);
#  #endif

#    /* If we initialize SIGQUIT to SIG_IGN, then the SIG_IGN will get
#       passed to the inferior, which we don't want.  It would be
#       possible to do a "signal (SIGQUIT, SIG_DFL)" after we fork, but
#       on BSD4.3 systems using vfork, that can affect the
#       GDB process as well as the inferior (the signal handling tables
#       might be in memory, shared between the two).  Since we establish
#       a handler for SIGQUIT, when we call exec it will set the signal
#       to SIG_DFL for us.  */
#    signal (SIGQUIT, do_nothing);
#  #ifdef SIGHUP
#    if (signal (SIGHUP, do_nothing) != SIG_IGN)
#      signal (SIGHUP, disconnect);
#  #endif
#    signal (SIGFPE, float_handler);

#  #if defined(SIGWINCH) && defined(SIGWINCH_HANDLER)
#    signal (SIGWINCH, SIGWINCH_HANDLER);
#  #endif
#  }

}

sub DESTROY { destroy @_ } 
    
'END';



