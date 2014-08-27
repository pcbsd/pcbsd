<?

function do_service_action()
{
  global $pbiorigin;
  global $sc;
  global $jail;

  $sname=$_GET['service'];
  $sscript=$_GET['servicerc'];
  $action=$_GET['action'];
  if ( empty($sname) or empty($sscript) or empty($action) )
    return;

  if ( $jail == "#system" )
     $output = run_cmd("service $action $sname $sscript #system");
  else {
     // Get jail ID
     exec("$sc ". escapeshellarg("jail ". $jail . " id"), $jarray);
     $jid=$jarray[0];
     $output = run_cmd("service $action $sname $sscript $jid");
  }

  if ( $action == "start" )
     echo "Started $sname on $jail<br>";  
  if ( $action == "stop" )
     echo "Stopped $sname on $jail<br>";  
  if ( $action == "restart" )
     echo "Restarted $sname on $jail<br>";  

   $newUrl=http_build_query($_GET);
   $app=str_replace("/", "%2F", $app);
   $newUrl=str_replace("&service=$sname", "", $newUrl);
   $newUrl=str_replace("service=$sname", "", $newUrl);
   $newUrl=str_replace("&servicerc=$sscript", "", $newUrl);
   $newUrl=str_replace("servicerc=$sscript", "", $newUrl);
   $newUrl=str_replace("&action=$action", "", $newUrl);
   $newUrl=str_replace("action=$action", "", $newUrl);
   hideurl("?".$newUrl);
}

function parse_service_start()
{
  global $pbicdir;
  global $pbiorigin;
  global $pbiindexdir;
  global $jail;
  global $jailUrl;
  global $sc;

  $lines = file($pbicdir . "/service-start");
  foreach($lines as $line_num => $line)
  {
    $cline = trim($line);
    if ( empty($cline) )
       continue;
    if ( strpos($cline, "#") === 0 )
       continue;

    $sline = preg_replace("/[[:blank:]]+/"," ",$cline);
    $sarray = explode(" ", $sline);
    
    // lets check if this service is enabled in etc/rc.conf
    if ( $jail == "#system" )
       $rcconf="/etc/rc.conf";
    else {
       // Get jail path
       exec("$sc ". escapeshellarg("jail ". $jail . " path"), $jarray);
       $rcconf=$jarray[0] . "/etc/rc.conf";
    }

    // Now look if the service is already enabled
    $sflag = $sarray[0] . '_enable="YES"';
    $contents = file_get_contents($rcconf);
    $pattern = preg_quote($sflag, '/');
    $pattern = "/^.*$pattern.*\$/m";
    if (preg_match_all($pattern, $contents, $matches))
       $senabled=true;
    else
       $senabled=false;

    if ( $senabled ) {
      echo "                     <li><a href=\"?p=appinfo&app=".rawurlencode($pbiorigin)."&jail=$jailUrl&service=$sarray[0]&servicerc=$sarray[1]&action=stop\"><img src=\"/images/application-exit.png\" height=24 width=24> Stop $sarray[0]</a></li>\n";
      echo "                     <li><a href=\"?p=appinfo&app=".rawurlencode($pbiorigin)."&jail=$jailUrl&service=$sarray[0]&servicerc=$sarray[1]&action=restart\"><img src=\"/images/restart.png\" height=24 width=24> Restart $sarray[0]</a></li>\n";
    } else
      echo "                     <li><a href=\"?p=appinfo&app=".rawurlencode($pbiorigin)."&jail=$jailUrl&service=$sarray[0]&servicerc=$sarray[1]&action=start\"><img src=\"/images/start.png\" height=24 width=24> Start $sarray[0]</a></li>\n";

  }

}

function parse_service_config()
{
  global $pbicdir;
  global $pbiorigin;
  global $pbiindexdir;
  global $jail;
  global $sc;

  $lines = file($pbicdir . "/service-configure");
  foreach($lines as $line_num => $line)
  {
    $cline = trim($line);
    if ( empty($cline) )
       continue;
    if ( strpos($cline, "#") === 0 )
       continue;

    $sline = preg_replace("/[[:blank:]]+/"," ",$cline);
    $sarray = explode(" ", $sline);
    
    if ( $jail == "#system" )
      $ip = "localhost";
    else {
      // Get jail address
      exec("$sc " 
           . escapeshellarg("jail ". $jail . " ipv4")
           , $jarray);
      $ip = $jarray[0];
      $ip = substr($ip, 0, strpos($ip, "/"));
    }

    // Split up our variables
    $stype = array_shift($sarray);
    $surl = array_shift($sarray);
    foreach( $sarray as $selem)
      $snickname = $snickname . " " . $selem;

    if ( $stype == "URL" ) {
      $newurl = str_replace("{IP}", $ip, $surl);
      if ( strpos($newurl, "http") === false )
         $newurl = "http://" . $newurl;
      echo "                     <li><a href=\"$newurl\" target=\"_new\"><img src=\"/images/configure.png\" height=24 width=24> $snickname</a></li>\n";
    }

  }

}

function display_service_details()
{
  global $pbicdir;

  // Does this have rc.d scripts to start?
  if ( file_exists($pbicdir . "/service-start") )
     parse_service_start();

  // Check if this has a service configuration 
  if ( file_exists($pbicdir . "/service-configure") )
     parse_service_config();

}

function display_install_chooser()
{
  global $pbiorigin;
  global $pbiname;
  global $jailUrl;
  global $jail;

?>
<nav id="installwidget" role="navigation">
        <a href="#installwidget" title="Add / Remove Menu">Add / Remove Menu</a>
        <a href="#" title="Hide Menu">Hide Menu</a>
        <ul class="clearfix">
<?

   // Check if this app is installed
   $pkgoutput = syscache_ins_pkg_list("$jail");
   $pkglist = explode(", ", $pkgoutput[0]);
   if ( array_search($pbiorigin, $pkglist) !== false) {
     display_service_details();
     if ( $jail == "#system")
           echo "                     <li><a href=\"#\" onclick=\"delConfirm('" . $pbiname ."','".rawurlencode($pbiorigin)."','pbi','".$jailUrl."'); return false;\"><img src=\"/images/remove.png\" height=24 width=24> Delete</a></li>\n";
	else
           echo "                     <li><a href=\"#\" onclick=\"delConfirm('" . $pbiname ."','".rawurlencode($pbiorigin)."','pbi','".$jailUrl."'); return false;\"><img src=\"/images/remove.png\" height=24 width=24> Delete from jail: $jailUrl</a></li>\n";

     } else {
	if ( $jailUrl == "#system")
           echo "                     <li><a href=\"#\" onclick=\"addConfirm('" . $pbiname ."','".rawurlencode($pbiorigin)."','pbi','".$jailUrl."'); return false;\"><img src=\"/images/install.png\" height=24 width=24> Install</a></li>\n";
        else
           echo "                     <li><a href=\"#\" onclick=\"addConfirm('" . $pbiname ."','".rawurlencode($pbiorigin)."','pbi','".$jailUrl."'); return false;\"><img src=\"/images/install.png\" height=24 width=24> Install into jail: $jailUrl</a></li>\n";
     }

?>
        </ul>
</nav>

<?

}

function display_app_link($pbilist, $jail)
{

  $rlist = explode(" ", $pbilist);
  $totalCols = 2;
  $col = 1;
  echo " <table class=\"jaillist\" style=\"width:100%\">";
  echo "  <tr>\n";
  echo "   <th></th>\n";
  echo "   <th></th>\n";
  echo "  </tr>";

  foreach($rlist as $related) {
    parse_details($related, $jail, $col);
    if ( $col == $totalCols )
       $col = 1;
    else
       $col++;
    }

    // Close off the <tr>
    if ( $col == $totalCols )
       echo "  </tr>\n";

    echo "</table>\n";
}

  // Start the main script now
  if ( empty($_GET['app']) )
     die("Missing app=");

  $pbiorigin = $_GET['app'];

  // Check if we are starting / stopping a service
  if ( ! empty($_GET['service']) )
     do_service_action();

  $repo="remote";
  // Load the PBI details page
  $cmd="pbi app $pbiorigin";
  exec("$sc ". escapeshellarg("$cmd name") 
     . " " . escapeshellarg("pkg $jail $repo $pbiorigin version") 
     . " " . escapeshellarg("$cmd author")
     . " " . escapeshellarg("$cmd website") 
     . " " . escapeshellarg("$cmd comment")
     . " " . escapeshellarg("$cmd confdir")
     . " " . escapeshellarg("$cmd description")
     . " " . escapeshellarg("pkg $jail $repo $pbiorigin name")
     , $pbiarray);

  $pbiname = $pbiarray[0];
  $pbiver = $pbiarray[1];
  $pbiauth = $pbiarray[2];
  $pbiweb = $pbiarray[3];
  $pbicomment = $pbiarray[4];
  $pbicdir = $pbiarray[5];
  $pbidesc = $pbiarray[6];

  if ( empty($pbiname) or $pbiname == "$SCERROR" ) {
     $isPBI = false;
     $pbiname = $pbiarray[7];
  } else {
     $isPBI = true;
  }

  if ( empty($pbiname) )
    die("No such app: $pbi");

  if ( $isPBI ) {
    // Get second tier PBI data
    $cmd="pbi app $pbiorigin";
    unset($pbiarray);
    exec("$sc ". escapeshellarg("$cmd license") 
      . " " . escapeshellarg("$cmd type") 
      . " " . escapeshellarg("$cmd tags") 
      . " " . escapeshellarg("$cmd relatedapps") 
      . " " . escapeshellarg("$cmd plugins") 
      . " " . escapeshellarg("$cmd options") 
      . " " . escapeshellarg("$cmd rating")
     . " " . escapeshellarg("$cmd screenshots")
      , $pbiarray);
    $pbilicense = $pbiarray[0];
    $pbitype = $pbiarray[1];
    $pbitags = $pbiarray[2];
    $pbirelated = $pbiarray[3];
    $pbiplugins = $pbiarray[4];
    $pbioptions = $pbiarray[5];
    $pbirating = $pbiarray[6];
    $pbiss = $pbiarray[7];

  } else {

    // Not a PBI, fallback to loading data from PKGNG
    exec("$sc ". escapeshellarg("pkg $jail $repo $pbiorigin maintainer") 
       . " " . escapeshellarg("pkg $jail $repo $pbiorigin website")
       . " " . escapeshellarg("pkg $jail $repo $pbiorigin comment")
       . " " . escapeshellarg("pkg $jail $repo $pbiorigin description")
       , $pkgarray);
    $pbiauth = $pkgarray[0];
    $pbiweb = $pkgarray[1];
    $pbicomment = $pkgarray[2];
    $pbidesc = $pkgarray[3];

  }

  // Get the current work queue status of the dispatcher
  $dStatus = getDispatcherStatus();
?>
   
<br>
<table class="jaillist" style="width:420px">
  <tr>
    <th colspan=2>
      <? 
         echo "$pbiname - $pbiver"; 
 	 if ( "$jail" != "#system" )
           echo " ($jail)";
      ?>
    </th>
  </tr>
  <tr>
     <td width="60">
      <?
 	 $appbusy=false;
         foreach($dStatus as $curStatus) {
  	   if ( strpos($curStatus, "pbi $pbiorigin") !== false ) {
	      $appbusy=true;
	      break;
	   }
  	   if ( strpos($curStatus, "pkg $pbiorigin") !== false ) {
	      $appbusy=true;
	      break;
	   }
         }
	 if ( $appbusy ) {
	   print("<img align=\"center\" valign=\"center\" src=\"images/working.gif\" title=\"Working...\">");
	   echo("<script>setTimeout(function () { location.reload(1); }, 8000);</script>");
         } else {
	   display_install_chooser();
	 }
      ?>
    </td>
    <td align=left>
      <img align="left" height=64 width=64 src="images/pbiicon.php?i=<? echo "$pbicdir"; ?>/icon.png">
       <a href="<? echo "$pbiweb"; ?>" target="_new"><? echo "$pbiauth"; ?></a><br>
       Version: <b><? echo "$pbiver"; ?></b><br>
     </td>
  </tr>
  <tr>
    <td colspan="2">
       <p><? echo $pbidesc; ?></p>
    </td>
  </tr>

<? if ( $isPBI) { ?>

  <tr>
    <td colspan="2">
<div id="tab-container" class='tab-container'>
   <ul class='etabs'>
     <?  if ( ! empty($pbiss) ) { ?>
     <li class='tab'><a href="#tabs-screenshots">Screenshots</a></li>
     <? } ?>
     <?  if ( ! empty($pbirelated) ) { ?>
     <li class='tab'><a href="#tabs-related">Related</a></li>
     <? } ?>
     <?  if ( ! empty($pbiplugins) ) { ?>
     <li class='tab'><a href="#tabs-plugins">Plugins</a></li>
     <? } ?>
     <?  if ( ! empty($pbioptions) ) { ?>
     <li class='tab'><a href="#tabs-options">Options</a></li>
     <? } ?>
   </ul>
   <div class="panel-container">
     <?  // Do we have screenshots to display?
         if ( ! empty($pbiss) ) {
            echo "<div id=\"tabs-screenshots\">\n";
            $sslist = explode(" ", $pbiss);
            foreach($sslist as $screenshot)
              echo "<a href=\"$screenshot\" target=\"_new\"><img border=0 src=\"$screenshot\" height=50 width=50></a>&nbsp;";
	    echo "</div>\n";
         }

	 // Do we have related items to show?
         if ( ! empty($pbirelated) ) {
            echo "<div id=\"tabs-related\">\n";
	    display_app_link($pbirelated, $jail);
	    echo "</div>\n";
         }

	 // Do we have plugins to show?
         if ( ! empty($pbiplugins) ) {
            echo "<div id=\"tabs-plugins\">\n";
	    display_app_link($pbiplugins, $jail);
	    echo "</div>\n";
         }

	 // Do we have options to show?
         if ( ! empty($pbioptions) ) {
            echo "<div id=\"tabs-options\">\n";
            $olist = explode(" ", $pbioptions);
            foreach($olist as $option)
              echo "  <b>$option</b><br>\n";
	    echo "</div>\n";
         }
     ?>
   </div>
</div>
    </td>
  </tr>

<? } ?>

</table>

<script type="text/javascript">
  $('#tab-container').easytabs();
</script>
