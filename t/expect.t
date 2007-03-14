use Test::More ;

qx/gdb -v/ or
  plan skip_all => "cannot execute 'gdb', please use -execfile => '/full/path/to/gdb' ";

qx/tr --version/ or
  plan skip_all => "cannot execute 'tr'";

eval "use Expect; 1" or
  plan skip_all => "cannot use 'Expect'" ;

plan tests => 8;

use_ok('Devel::GDB');
my $gdb = new Devel::GDB ( '-params' => '-q',
                           '-create-expect' => 1 );
ok($gdb);

my $e = $gdb->get_expect_obj;
ok($e);

ok($gdb->send_cmd("file tr"));
ok($gdb->send_cmd("set args a-zA-Z A-Za-z"));
ok($gdb->send_cmd("-exec-run"));

$e->send("one TWO\n");
$e->send("ONE two\n");

ok($e->expect(undef, '-re', '^.+$')
    and $e->match =~ /^ONE two/);

ok($e->expect(undef, '-re', '^.+$')
    and $e->match =~ /^one TWO/);

$gdb->end;
