use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

WriteMakefile(
    'NAME'		=> 'Devel::GDB',
    'VERSION_FROM'	=> 'GDB.pm', # finds $VERSION
    'PREREQ_PM'		=> {'Devel::GDB' => 1.00 }, # e.g., Module::Name => 1.1 
    ($] >= 5.005 ?    ## Add these new keywords supported since 5.005 
      (ABSTRACT_FROM => 'GDB.pm', # retrieve abstract from module
       AUTHOR     => 'Josef Ezra <jezra@emc.com>') : () ),
);
