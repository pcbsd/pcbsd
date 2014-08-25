<?

// Set the error string syscache returns if a particular request
// isn't available
$SCERROR="[ERROR] Information not available";

function hideurl($newurl = "")
{
   if (empty($newurl) )
     $p = "/?p=" . $_GET['p'];
   else
     $p = "$newurl";
   ?>
   <script>
	window.history.pushState('AppWeb', 'AppWeb', '<? echo $p; ?>');
   </script>
   <?
}

// Runs commands through the sudo dispatcher
function run_cmd($cmd)
{
   exec("/usr/local/bin/sudo /usr/local/share/appweb/dispatcher $cmd", $output);
   return $output;
}

function syscache_ins_pkg_list($jail="")
{
   if ( empty($jail) )
      $jail = "#system";
   else
      $jail = "$jail";

   exec("/usr/local/bin/syscache ".escapeshellarg("pkg $jail installedlist"), $output);
   return $output;
}

function syscache_pbidb_list()
{
   exec("/usr/local/bin/syscache ".escapeshellarg("pbi list apps"), $output);
   return $output;
}

function queueInstallApp()
{
   $app = $_GET['installApp'];
   $type = $_GET['installAppCmd'];
   $target = $_GET['installAppTarget'];
   if ( ! empty($app) and ! empty($type) and ! empty($target) )
      run_cmd("queue $type $app install $target");

   // Now we can remove those values from the URL
   $newUrl=http_build_query($_GET);
   $app=str_replace("/", "%2F", $app);
   $newUrl=str_replace("&installApp=$app", "", $newUrl);
   $newUrl=str_replace("installApp=$app", "", $newUrl);
   $newUrl=str_replace("&installAppCmd=$type", "", $newUrl);
   $newUrl=str_replace("installAppCmd=$type", "", $newUrl);
   $newUrl=str_replace("&installAppTarget=$target", "", $newUrl);
   $newUrl=str_replace("installAppTarget=$target", "", $newUrl);
   hideurl("?".$newUrl);
}

function queueDeleteApp()
{
   $app = $_GET['deleteApp'];
   $type = $_GET['deleteAppCmd'];
   $target = $_GET['deleteAppTarget'];
   if ( ! empty($app) and ! empty($type) and ! empty($target) )
      run_cmd("queue $type $app delete $target");

   // Now we can remove those values from the URL
   $newUrl=http_build_query($_GET);
   $app=str_replace("/", "%2F", $app);
   $newUrl=str_replace("&deleteApp=$app", "", $newUrl);
   $newUrl=str_replace("deleteApp=$app", "", $newUrl);
   $newUrl=str_replace("&deleteAppCmd=$type", "", $newUrl);
   $newUrl=str_replace("deleteAppCmd=$type", "", $newUrl);
   $newUrl=str_replace("&deleteAppTarget=$target", "", $newUrl);
   $newUrl=str_replace("deleteAppTarget=$target", "", $newUrl);
   hideurl("?".$newUrl);
}

function getDispatcherStatus()
{
   return run_cmd("status");
}

function get_installed_list($target = "#system")
{
  global $sc;
  exec("$sc ". escapeshellarg("pkg " . $target . " installedlist"), $insarray);
  return explode(", ", $insarray[0]);
}

function parse_details($pbiorigin, $jail, $col, $showRemoval=false)
{
  global $sc;
  global $jailUrl;
  global $totalCols;
  global $inslist;
  global $SCERROR;

  if ( empty($jail) )
    $jail="#system";

  if ( empty($inslist) )
    $inslist = get_installed_list($jail);

  $cmd="pbi app $pbiorigin";
  exec("$sc ". escapeshellarg("$cmd name")
    . " " . escapeshellarg("pkg $jail local $pbiorigin version") 
    . " " . escapeshellarg("$cmd comment") 
    . " " . escapeshellarg("$cmd confdir")
    . " " . escapeshellarg("pkg $jail remote $pbiorigin name") 
    . " " . escapeshellarg("pkg $jail remote $pbiorigin version")
    . " " . escapeshellarg("pkg $jail remote $pbiorigin comment")
    . " " . escapeshellarg("$cmd type")
    , $pbiarray);

  $pbiname = $pbiarray[0];
  $pbiver = $pbiarray[1];
  $pbicomment = $pbiarray[2];
  $pbicdir = $pbiarray[3];
  if ( empty($pbiname) or $pbiname == "$SCERROR" )
    $pbiname = $pbiarray[4];
  if ( empty($pbiver) or $pbiver == "$SCERROR" )
    $pbiver = $pbiarray[5];
  if ( empty($pbicomment) or $pbicomment == "$SCERROR" )
    $pbicomment = $pbiarray[6];
  $pbitype = $pbiarray[7];

 
  global $viewType;
  if ( $jail != "#system" ) {
     // In jails we only list Server types, unless user requested CLI also
     if ( $pbitype != "Server" and $viewType != "ALL" )
	return 1;

     // In a jail, filter out Graphical types
     if ( $pbitype == "Graphical" )
	return 1;
  }

  if ( $col == 1 )
    print ("<tr>\n");

  // Get our values from this line
  print("  <td>\n");

  // Is this app installed?
  if ( array_search($pbiorigin, $inslist) !== false and $showRemoval)
   print("    <button title=\"Delete this application\" style=\"float:right;\" onclick=\"delConfirm('" . $pbiname ."','".$pbiorigin."','pbi','".$jailUrl."')\">X</button>\n");

  print("    <a href=\"/?p=appinfo&app=$pbiorigin&jail=$jailUrl\" title=\"$pbicomment\"><img border=0 align=\"center\" height=48 width=48 src=\"/images/pbiicon.php?i=$pbicdir/icon.png\" style=\"float:left;\"></a>\n");
  print("    <a href=\"/?p=appinfo&app=$pbiorigin&jail=$jailUrl\" style=\"margin-left:5px;\">$pbiname</a><br>\n");
  print("    <a href=\"/?p=appinfo&app=$pbiorigin&jail=$jailUrl\" style=\"margin-left:5px;\">$pbiver</a>\n");
  print("  </td>\n");

  if ( $col == $totalCols )
    print ("</tr>\n");

  return 0;
}

function display_cats($iconsize = "32")
{
  global $sc;
  global $jailUrl;
  exec("$sc ". escapeshellarg("pbi list cats"), $catarray);
  $catlist = explode(", ", $catarray[0]);
  foreach ( $catlist as $cat ) {
    if ( empty($cat) )
      continue;
    exec("$sc ". escapeshellarg("pbi cat $cat name"). " " . escapeshellarg("pbi cat $cat icon"). " " . escapeshellarg("pbi cat $cat comment"), $catdetails);
    echo "<img height=$iconsize width=$iconsize src=\"/images/pbiicon.php?i=$catdetails[1]\"><a href=\"?p=appcafe&cat=$cat&jail=$jailUrl\" title=\"$catdetails[2]\">$catdetails[0]</a><br>";
    unset($catdetails);
  }

}

function get_jail_list()
{
  global $sc;
  global $jail_list_array;

  // If this is set, we have the jail list already
  if ( ! empty( $jail_list_array) )
     return $jail_list_array;

  // Query the system for the jail list
  exec("$sc ". escapeshellarg("jail list")
       . " " . escapeshellarg("jail stoppedlist")
       , $jail_list_array);

  return $jail_list_array;

}

function display_jail_menu()
{

   $jailoutput = get_jail_list();
   $running=$jailoutput[0];
   $stopped=$jailoutput[1];
   $rarray = explode( " ", $running);
   $sarray = explode( " ", $stopped);

  if ( ! empty($running) ) {
    echo "<b>Running Jails</b><hr align=\"left\" width=\"85%\">";
    foreach ($rarray as $jail)
      print("<a href=\"?p=jailinfo&jail=$jail\" style=\"color:green\">$jail</a><br>");
  }

  if ( ! empty($stopped) ) {
    echo "<br><br><b>Stopped Jails</b><hr align=\"left\" width=\"85%\">";
    foreach ($sarray as $jail)
      print("<a href=\"?p=jailinfo&jail=$jail\" style=\"color:red\">$jail</a><br>");
  }

}

?>
