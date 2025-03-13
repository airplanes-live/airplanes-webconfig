<html>
<head>
<meta name="viewport" content="width=device-width, initial-scale=1">
<link href="../css/bootstrap.min.css" rel="stylesheet">
<script src="../js/bootstrap.min.js"></script>
<style>
    .btn-margin-bottom {
        margin-bottom: 5px !important;
    }

    body {
        background-color: #343434;
        color: #FFF;
    }

    .adsbx-green {
        color: #FFF;
    }

    .container-margin {
        padding: 5px 10px !important;
    }

    .logo-margin {
        padding: 10px 0px !important;
    }

    .btn-primary {
        /*width: 325px;*/
        padding: 10px;
        text-align: left;
        color: #fff;
        border-color: #545454;
        background-color: #828282;
    }

    .alert-success {
        color: #FFF;
        font-weight: 900;
        background-color: #064b75;
        border-color: #fff;
    }

    .min-adsb-width {
        /*width: 325px;*/
    }

    .container-padding {
        padding: 5px;
    }
    #wifiSelect {
     width: 100%;
    }
</style>


<?php
session_start();
if ($_SESSION['authenticated'] != 1) {
    $_SESSION['auth_URI'] = $_SERVER['REQUEST_URI'];
    header("Location: ../auth/");
}
?>

</head>
<body onload="selectDefaults()">

<script type="text/javascript">

function otherssidCheck(arg) {
    if (document.getElementById('wifiSelect') == null) {
        return;
    }
    if (arg == 'ssid' && document.getElementById('ssidCheckbox').checked) {
        document.getElementById('wifiSelect').selectedIndex = -1;
        document.getElementById('wifiSelect').style.display = 'none';

        document.getElementById('dropdownCheckbox').checked = false;
	    
        document.getElementById('ssidInput').style.display = 'initial';
    } else {
        document.getElementById('wifiSelect').selectedIndex = 0;
        document.getElementById('dropdownCheckbox').checked = true;
        document.getElementById('ssidCheckbox').checked = false;

        document.getElementById('wifiSelect').style.display = 'initial';

        document.getElementById('ssidInput').style.display = 'none';
    }
}

function selectDefaults() {
    otherssidCheck('dropdown');
}


</script>

    <center>

	<br></br>
	<img src="../img/airplanes.svg" width="75"/>
	<br></br>
	<h6>airplanes.live Feeder Image <br />version <?php echo file_get_contents("/boot/airplanes-version"); ?></h6>
        <a class="btn btn-primary" href="../">(..back to main menu)</a><br /><br />
    <form method='POST' action="./index.php" onsubmit="return confirm('Save WiFi and reboot the unit?');">

<?php

$newssid ='';
$newbssid ='';

if(isset($_POST['wifiChoose'])) {
    $newssid = $_POST["wifiChoose"];
} else if (isset($_POST["customSSID"])) {
    $newssid = $_POST["customSSID"];
}

if (!empty($newssid) || !empty($newbssid)) {

    $newpassword = $_POST["wifipassword"];
    $newssid = str_replace(array("\n", "\t", "\r"), '', $newssid);

    $newcountry = $_POST["wifiChooseCountry"];
    $newcountry = str_replace(array("\n", "\t", "\r"), '', $newcountry);

$content = '[connection]
id=airplanes-uiconfig
uuid=b34c618e-f46b-45df-9039-8e84a865b2ea
type=wifi
autoconnect-priority=10

[wifi]
mode=infrastructure';
if (!empty($newssid)) {
        $content .= '
ssid=' . $newssid;
    } else {
        $content .= '
bssid=' . $newbssid;
    }

if (!empty($newpassword)) {
        $content .= '
	
[wifi-security]';
}

$content .= '
key-mgmt=wpa-psk
psk=' . $newpassword;
	
$content .= '

[ipv4]
method=auto

[ipv6]
addr-gen-mode=default
method=auto

[proxy]

';

file_put_contents("/tmp/webconfig/airplanes-uiconfig.nmconnection", $content);
file_put_contents("/tmp/webconfig/wificountry", $newcountry);
	
?>
    <script type="text/javascript">
    var timeleft = 70;

    var downloadTimer = setInterval(function(){

        if(timeleft <= 0){
            clearInterval(downloadTimer);
            window.location.replace("../index.php");
        }
        document.getElementById("progressBar").style.width = (70 - timeleft) + "%";
        timeleft -= 1;
    }, 1000);
    </script>
        <div class="progress">
                <div id="progressBar" class="progress-bar progress-bar-striped progress-bar-animated" role="progressbar" aria-valuenow="0" aria-valuemin="0" aria-valuemax="70" style="width: 1%"></div>
        </div>
	<?php

	system('sudo /airplanes/webconfig/helpers/install-wpasupp.sh > /dev/null 2>&1 &');
	exit;
}
?>
    <h3>Choose WiFi Network:</h3>
    (Note 1: 2.4GHz networks have longer range than 5.2GHz networks)<br /><br />
    (Note 2: If the network name is not in the dropdown, please specify it)<br /><br />
        <div class="container col-8">
        <table  class="table table-striped table-hover table-dark">
        <tr><td>
            <br />
            <input class="form-check-input" type="checkbox" id="dropdownCheckbox" onclick="javascript:otherssidCheck('dropdown');" />
            <label class="form-check-label">Choose Wifi Network &emsp;</label>
            <br /><br />
            <input class="form-check-input" type="checkbox" id="ssidCheckbox" onclick="javascript:otherssidCheck('ssid');" />
            <label class="form-check-label">Specify Network name (SSID)&emsp;</label>
            <br /><br />
            <div><br />
               <div class="form-group">
               <select name="wifiChoose" class="custom-select custom-select-lg btn btn-secondary" id="wifiSelect">
                    <option name="SSID" value="" selected>Choose Network ...</option>
  			<?php
   				 $lines = file('/tmp/webconfig/wifi_scan');
   				 foreach($lines as $line) {
        				echo '<option onclick="javascript:otherssidCheck();" value="'.$line.'">'.$line.'</option>';
    				}
    			?>
               </select>
               </div>
            </div>
            <div id="ssidInput" style="display:none">
                <input class="form-control form-control-lg" type="text" id="customSSID" name="customSSID" />
            </div>		
        </td></tr>
	<tr><td>WiFi Password:
	    <br /><br />
            <input class="form-control form-control-lg" type="text" name="wifipassword"  id="wifiSelect" pattern="^[\u0020-\u007e]{8,63}$" />
        </td></tr>		
        <tr><td>
            <br />
            Choose Wifi Country:<br /><br />
	    <div class="form-group">
            <select name="wifiChooseCountry" class="custom-select custom-select-lg btn btn-secondary" id="wifiSelectCountry">
                
		<?php
			$country_json = file_get_contents('country_codes.json');
			$country_codes = json_decode($country_json, true);
			$current_country = file_get_contents('/tmp/webconfig/wificountry');
			foreach($country_codes as [$code, $country]) {
   				if($code == trim($current_country)){
        				echo '<option value="'.$code.'" selected>'.$country.' - '.$code.'</option>';
    				} else {
        				echo '<option value="'.$code.'">'.$country.' - '.$code.'</option>';
    				}
			}
			echo trim($current_country) . 'x' . $code;
		?>\
	    </select>
            </div>
        </td></tr>
        </table>
    </div>
<input class="btn btn-primary" type="submit" value="Submit">
</form>

<br /> <br />
 Current WiFi Status:

<table>
<tr>
<td>
<?php
$output = shell_exec('iwconfig wlan0');
echo "<pre>$output</pre>";
?>
</td></tr></table>

 <br>
 Current IP Status:

<table><tr><td>
<?php
$output = shell_exec('ifconfig');
echo "<pre>$output</pre>";
?>
</td></tr>
</table>

 <br>
 WiFi BSSIDs / frequencies:

<table><tr><td>
<?php
$output = shell_exec('cat /tmp/webconfig/wifi_bssids');
echo "<pre>$output</pre>";
?>
</td></tr>
</table>

</center>
</body>
</html>
