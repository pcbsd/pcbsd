<?
  require("include/Mobile_Detect.php");
  require("include/globals.php");
  require("include/functions.php");

  // Figure out what page is being requested
  $jail = "";
  if ( ! empty($_GET['jail'])) {
     if ( $_GET['jail'] == "__system__") {
        $jail = "#system";
        $jailUrl = "__system__";
     } else {
        $jail = $_GET['jail'];
        $jailUrl = $_GET['jail'];
     }

  }

  // Do any install / delete requests
  if ( ! empty($_GET["deleteApp"]) )
     queueDeleteApp();
  if ( ! empty($_GET["installApp"]) )
     queueInstallApp();

  // Figure out what page is being requested
  if ( empty($_GET["p"]))
     $page = "appcafe";
  else
     $page = $_GET["p"];

  // Set some globals for mobile detection
  $detect = new Mobile_Detect;
  $deviceType = ($detect->isMobile() ? ($detect->isTablet() ? 'tablet' : 'phone') : 'computer');
  $scriptVersion = $detect->getScriptVersion();

  require("include/header.php");

  if ( $deviceType == "computer" )
    require("include/nav-computer.php");
  else
    require("include/nav-phone.php");

  // Does the page exist?
  if ( file_exists("pages/$page.php") === false ) {
    require("pages/error.php");
  } else {
    require("pages/$page.php");
  }


  require("include/footer.php");
?>
