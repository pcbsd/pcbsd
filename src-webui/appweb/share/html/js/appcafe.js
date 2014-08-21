function delConfirm(appname, origin, cmd, target) {
    if (confirm("Are you sure you want to delete " + appname + "?") == true) {
	var newURL = window.location.pathname + window.location.search;
	window.location.href = newURL + "&deleteApp=" + origin + "&deleteAppCmd=" + cmd + "&deleteAppTarget=" + target;
    }
}

function addConfirm(appname, origin, cmd, target) {
    if (confirm("Are you sure you want to install " + appname + "?") == true) {
	var newURL = window.location.pathname + window.location.search;
	window.location.href = newURL + "&installApp=" + origin + "&installAppCmd=" + cmd + "&installAppTarget=" + target;
    }
}
