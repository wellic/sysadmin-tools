#!/usr/bin/php -q
<?php
# FROM PUPPET. DONT EDIT

# Vhost hentes fra tools.bellcom.dk/vhost.txt

# Sæt $test til true for debug mode hvor kommandoerne kun udskrives
$test = false;
#$test = true;

# Kontrollerer om der er input fra kommando line
if(empty($_SERVER["argv"][1])) {
   echo "Usage: " . $_SERVER["argv"][0] . " <domain.tld>\n";
   exit(1);
}
else
{
  $sitename = $_SERVER['argv'][1];
  $sitename = chop($sitename);
}

# tjek for root rettigheder
if (!posix_getuid() == 0) {
  echo "Scriptet kræver root. Kør med sudo\n";
  exit(2);
}

# tjekker for pwgen
if (!file_exists('/usr/bin/pwgen')) {
  echo "pwgen er krævet for at generere passwords. (apt-get install pwgen) og prøv igen\n";
  exit(3);
}

# Printer system info til brugeren - til kontrol
print "\nSystemnavn: " . $sitename;
print "\n\n Tryk på Enter for at oprette sitet.";
$sysName = fread(STDIN, 80); // Read up to 80 characters or a newline

#Sætter alle faste variable.
$sitepath = "/var/www/";
$vhostaddress = "http://tools.bellcom.dk/vhost.txt";
$exec_genpasswd = "pwgen -N1 -s 10";
$passwd = exec($exec_genpasswd);
$username = preg_replace('/\./', '_', $sitename);
$dbname = preg_replace('/\-/', '_', $username);
$dbusername = substr($dbname, 0, 15);
$htpasswdfile = "/var/www/.htpasswd";

# findes sitet allerede?
if (file_exists($sitepath.$sitename)) {
  echo "\n$sitepath$sitename already exists. Aborting.\n";
  exit(4);
}

# findes databasebrugeren?
$systemcmd = "\nmysql -u root -e 'SELECT EXISTS(SELECT 1 FROM mysql.user WHERE user = \"$dbusername\");'";
$exists = exec($systemcmd);
if ($exists) {
  echo "\n$dbusername already exists as a mysql user. Aborting.\n";
  exit(5);
}

# Opretter dirs
print "\nOpretter site dirs\n";
$systemcmd = "\nmkdir -p $sitepath$sitename/tmp $sitepath$sitename/logs $sitepath$sitename/sessions $sitepath$sitename/public_html";
if ($test) {
  print "Udfører(Debug): " . $systemcmd . "\n ";
}
else {
  print "Udfører: " . $systemcmd . "\n ";
  system($systemcmd);
}

# Ejer og gruppe
print "\nEjer og gruppe\n";
$systemcmd = "\nchown -R www-data: $sitepath$sitename";
if ($test) {
  print "Udfører(Debug): " . $systemcmd . "\n ";
}
else {
  print "Udfører: " . $systemcmd . "\n ";
  system($systemcmd);
}

# Rettigheder
print "\nRettigheder\n";
$systemcmd = "\nchmod ug+rwX -R $sitepath$sitename";
if ($test) {
  print "Udfører(Debug): " . $systemcmd . "\n ";
}
else {
  print "Udfører: " . $systemcmd . "\n ";
  system($systemcmd);
}

# Tilretter vhost fil - kopier filen til /etc/apache2/sites-available
print "\nApache2 conf\n";
$systemcmd = "wget -q --output-document=/etc/apache2/sites-available/".$sitename." " . $vhostaddress . "";
if ($test) {
  print "Udfører(Debug): \n" . $systemcmd . "\n";
}
else {
  print "Udfører: \n" . $systemcmd . "\n";
  system($systemcmd);
}

$systemcmd = "perl -pi -e 's/\[domain\]/".$sitename."/g' /etc/apache2/sites-available/$sitename";
if ($test) {
  print "Udfører(Debug): \n" . $systemcmd . "\n";
}
else {
  print "Udfører: \n" . $systemcmd . "\n";
  system($systemcmd);
}

# Tester om serveren kører varnish, hvis ja, ret vhost til at køre på port 8080
$using_varnish = exec("netstat -tunap | grep LISTEN | egrep -c '0.0.0.0:80\ (.*)varnishd|:8080\ (.*)apache2'");
if ($using_varnish == 2) {
  $systemcmd = "perl -pi -e 's/\*:80\>/\*:8080\>/g' /etc/apache2/sites-available/$sitename";
  if ($test) {
    print "Udfører(Debug): \n" . $systemcmd . "\n";
  }
  else {
    print "Udfører: \n" . $systemcmd . "\n";
    system($systemcmd);
  }
}

# Enabler vhost
$systemcmd = "a2ensite " .$sitename."";
if ($test) {
  print "Udfører(Debug): \n" . $systemcmd . "\n";
}
else {
  print "Udfører: \n" . $systemcmd . "\n";
  system($systemcmd);
}

#Opretter mysql database og bruger
print "\nOpretter mysql database og bruger\n";
$systemcmd = "\nmysql -u root -e 'CREATE DATABASE $dbname'";
if ($test) {
  print "Udfører(Debug): " . $systemcmd . "\n";
}
else {
  print "Udfører: " . $systemcmd . "\n";
  system($systemcmd);
}
$systemcmd = "\nmysql -u root -e 'GRANT ALL ON $dbname.* TO $dbusername@localhost IDENTIFIED BY \"$passwd\"'";
if ($test) {
  print "Udfører(Debug): " . $systemcmd . "\n";
}
else {
  print "Udfører: " . $systemcmd . "\n";
  system($systemcmd);
}

# reload apache
$systemcmd = "/etc/init.d/apache2 reload";
if ($test) {
  print "Udfører(Debug): \n" . $systemcmd . "\n";
}
else {
  print "Udfører: \n" . $systemcmd . "\n";
  system($systemcmd);
}

# Mail and print info
$hostname = system("hostname");
mail("mmh@bellcom.dk","New site at $hostname","DBNAME = $dbname DBUSERNAME = $dbusername DBPASS = $passwd\nSitepath: $sitepath$sitename\n");

print "Ret evt. vhost'en med flere domæner og reload apache\n";
print "DBNAME = $dbname DBUSERNAME = $dbusername DBPASS = $passwd\n";
print "Sitepath: $sitepath$sitename\n";
?>

