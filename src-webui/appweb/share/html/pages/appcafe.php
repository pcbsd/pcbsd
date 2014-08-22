<?

function display_jail_appcafeselection()
{
?>
<table class="jaillist" style="width:768px">
<tr>
   <th>AppCafe Store selection</th>
</tr>
<?
   echo "<tr><td><a href=\"/?p=appcafe&jail=__system__\">Browse for System</a></td></tr>";
   $jailoutput = get_jail_list();

   $running=$jailoutput[0];
   $rarray = explode( " ", $running);

   foreach ($rarray as $jname) {
     if ( empty($jname) )
        continue;
     echo "<tr><td><a href=\"/?p=appcafe&jail=$jname\">Browse jail: $jname</a></td></tr>";
   }


?>
</table>
<?

} // End of display_jail_appcafeselection

   if ( empty($_GET['jail']) or ! empty($_GET['changeappcafejail']))
   {
      display_jail_appcafeselection();
   } else {

     if ( ! empty($_GET['cat']) )
       $header="Browsing Category: ". $_GET['cat'];
     else
       $header="Recommended Applications";
?>

<h1><? echo $header; ?></h1>
<br>
<?

       if ( $deviceType == "computer" ) { 
       $totalCols = 4;
?>
<table class="jaillist" style="width:768px">
<tr>
   <th></th>
   <th></th>
   <th></th>
   <th></th>
</tr>
<?
       } else {
         $totalCols = 2;
?>
<table class="jaillist" style="width:100%">
<tr>
   <th></th>
   <th></th>
</tr>
<?
       }

     if ( ! empty($_GET['cat']) )
     {
       exec("$sc ". escapeshellarg("pbi list apps"), $pbiarray);
       $fulllist = explode(", ", $pbiarray[0]);
       $catsearch = $_GET['cat'] . "/";
       $pbilist = array_filter($fulllist, function($var) use ($catsearch) { return preg_match("|^$catsearch|", $var); });

     } else {
       exec("$sc ". escapeshellarg("pbi list recommended")." ". escapeshellarg("pbi list new"), $pbiarray);
       $pbilist = explode(", ", $pbiarray[0]);
       $newlist = explode(", ", $pbiarray[1]);
     }

     // Now loop through pbi origins
     $col=1;
     foreach ($pbilist as $pbiorigin) {
       parse_details($pbiorigin, $jail, $col);
       if ( $col == $totalCols )
          $col = 1;
       else
         $col++;
     } 

     // Close off the <tr>
     if ( $col != $totalCols )
        echo "</tr>";

     echo "</table>";
   }
?>

