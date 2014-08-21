<?

function display_install_chooser()
{

  global $pbiorigin;
  global $pbiname;

  $jailarray = get_jail_list();
  $running=$jailarray[0];
  $rarray = explode( " ", $running);

  $tocheck = array("#system");
  $containers = array_merge($tocheck, $rarray);

?>
<nav id="installwidget" role="navigation">
        <a href="#installwidget" title="Add / Remove Menu">Add / Remove Menu</a>
        <a href="#" title="Hide Menu">Hide Menu</a>
        <ul class="clearfix">
<?

  foreach ( $containers as $target ) {
     if ( empty($target) )
        continue;

     // Check if this app is installed
     $pkgoutput = syscache_ins_pkg_list("$target");
     $pkglist = explode(", ", $pkgoutput[0]);
     if ( array_search($pbiorigin, $pkglist) !== false) {
	if ( $target == "#system")
           echo "                     <li><a href=\"#\" onclick=\"delConfirm('" . $pbiname ."','".$pbiorigin."','pbi','".$target."'); return false;\">Delete</a></li>\n";
	else
           echo "                     <li><a href=\"#\" onclick=\"delConfirm('" . $pbiname ."','".$pbiorigin."','pbi','".$target."'); return false;\">Delete from jail: $target</a></li>\n";

     } else {
	if ( $target == "#system")
           echo "                     <li><a href=\"#\" onclick=\"addConfirm('" . $pbiname ."','".$pbiorigin."','pbi','".$target."'); return false;\">Install</a></li>\n";
        else
           echo "                     <li><a href=\"#\" onclick=\"addConfirm('" . $pbiname ."','".$pbiorigin."','pbi','".$target."'); return false;\">Install into jail: $target</a></li>\n";
     }
  }

?>
        </ul>
</nav>

<?

}

function display_app_link($pbilist, $jail="#system")
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

  $jail="#system";

  $pbiorigin = $_GET['app'];

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
