<html>
 <head>
<?php
// Displays auto discovered v4 hosts
// by Craig Miller 20 April 2017
// 


// ===== Change these vars to valid values in your environment ====

// defaults
$path="/home/user/public_html/test";
$v4app="v4disc.sh -H -q -i eth0";
// ================================================================


?>
  <title>v4disc-html</title>
 </head>
 <body>
 
<H2 align="center">v4 Auto Discovery</H2>
<HR />
<?php
 
	$pipe = popen ("$path/$v4app ",  "r");
	while(!feof($pipe)) {
		$line = fgets($pipe, 1024);
		// show line as it comes from the pipe
		echo $line;
	}
	pclose($pipe);

?>
<HR />
<i>v4disc-html</i> by Craig Miller &copy; 2017<BR>
 </body>
</html>
