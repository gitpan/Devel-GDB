# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

#########################

use Test;
BEGIN { plan tests => 4 };

use Devel::GDB;
ok(1);                          # 1. If we made it this far, we're ok.

use vars qw/$gdb/ ; 
$gdb = Devel::GDB -> new()  ; 
ok(1) ;                         # 2. made it so far? (new exists)

ok(ref $gdb) ;                  # 3. returned a moudle? 

ok(scalar $gdb->get('help')) ;  # 4. gdb response? 

