#!/usr/bin/perl

###
# TEST01
###
use String::Random;
use Time::HiRes qw(usleep nanosleep);

my $randomObject;
my $randomIp;
$randomObject = new String::Random;

for ( my $i=0; $i < 10000; $i++ ) {

   # sleep n miliseconds
   usleep(10000);
   srand($i * time() ^ ($$ + ($$ << 15)));

   $randomIp = $randomObject->randpattern("CCcccccnn");
   print "randomIp: $randomIp\n";
   
   my $ip=join ('.', (int(rand(255))
            ,int(rand(255))
            ,int(rand(255))
            ,int(rand(255)))
   );
   print "randomStr: $ip\n";
   
   my %request = ( 
      client_address => $ip,
      sasl_username => $randomIp,
   );

   my %result = $postfwd_items_plugin{incr_client_country_login_count}->(%request);
   %result = $postfwd_items_plugin{client_uniq_country_login_count}->(%request);
}
