<? defined('DS') OR die('No direct access allowed.'); ?>
<div id="container" style="width:100%;height:100%;" taborder="0">

<nav id="nav" role="navigation">
	<a href="#nav" title="Show navigation">Show navigation</a>
	<a href="#" title="Hide navigation">Hide navigation</a>
	<ul class="clearfix">
		<li>
			<a href="/?p=appcafe&jail=<? echo "$jailUrl"; ?>" aria-haspopup="true"><span><img src="/images/appcafe.png" height=48 width=48> AppCafe <? if ( $jail == "#system" ) { echo "(Local System)"; } elseif (! empty($jail) ) { echo "($jail)"; } else { echo "(Select Jail)"; } ?></span></a>
                        <ul>
                                <li><a href="/?p=sysapp&jail=<? echo "$jailUrl"; ?>"><img src="/images/install.png" height=32 width=32> <? if ( $jail == "#system") { echo "System Applications"; } elseif (! empty($jail) ) { echo "$jail Applications"; } else { echo "Select System/Jail"; } ?></a></li>
                                <li><a href="/?p=appcafe-search&jail=<? echo "$jailUrl"; ?>"><img src="/images/search.png" height=32 width=32> App Search</a></li>
                                <li><a href="/?p=appcafe"><img src="/images/switch.png" height=32 width=32> Change System / Jail</a></li>
				<?
if (USERNAME)
  echo "                             <li><a href=\"/?logout=true\"><img src=\"/images/logout.png\" height=32 width=32> Logout</a></li>";
				?>
                        </ul>

		</li>
		<li>
			<a href="/?p=jails" aria-haspopup="true"><span><img src="/images/warden.png" height=48 width=48> Warden</span></a>
                        <ul>
                                <li><a href="/?p=jails"><img src="/images/jail.png" height=24 width=24> Browse Jails</a></li>
                                <li><a href="/?p=jailcreate"><img src="/images/add.png" height=24 width=24> Create Jail</a></li>
                        </ul>

		</li>
	</ul>
</nav>

<body>
<div id="leftmenu" style="height:100%;width:12.00em;position:absolute;margin-top:3.80em;marin-left:10px;">
  <? 
     require("include/leftmenu.php");
  ?>

</div>

<script type="text/javascript">
$(document).ready(function () {
    var interval = 10000;   //number of mili seconds between each call
    var refresh = function() {
        $.ajax({
            url: "/pages/notifier.php",
            cache: false,
            success: function(html) {
                $('#notifier').html(html);
                setTimeout(function() {
                    refresh();
                }, interval);
            }
        });
    };
    refresh();
});
</script>
<div id="notifier" style="height:35px;width:600px;position:absolute;margin-top:3.80em;margin-left:12.50em;"></div>

<div id="body" style="height:100%;width:700px;position:absolute;margin-top:6.50em;margin-left:12.50em;">
