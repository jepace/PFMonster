<?php
if (!isset($_GET['user_name']))
    $user_name = "";
else
    $user_name = $_GET['user_name'];
         
// We will receive error messages
// from the validation page
if (!isset($_GET['error']))
    $error = '';
else
    $error = $_GET['error'];
?>

<html>
<head>
    <title> PFMonster </title>
    <meta name="viewport" content="width=device-width;
        initial-scale=1.0; maximum-scale=1.0; user-scalable=0;"/>
<?php
    $user_name = strtolower ($user_name);
    if ($user_name != "")
        echo "    <meta http-equiv=\"refresh\" content=\"5\">\n";
?>
</head>

<body>
    <h3> PFMonster </h3>

<?php
//phpinfo();

// If we don't have a username, have user login...
if ($user_name == '') {
?>

<form method="POST" action="./validate.php">
    <p>
        <i> User: </i>
        <input type="text" name="user_name" value="<?php echo $user_name; ?>">
    </p>
    <input type="submit" value="Login">
</form>

<?php
    } // end if blank username
else
{
    echo '<i>User:</i> ', $user_name, '<br>';

    // Database check
    $db_handle = pg_pconnect("dbname=pfm user=pgsql");   
    $query = "SELECT timeleft, today, isrunning FROM pfm WHERE login = '$user_name'";
    $result = pg_exec($db_handle, $query);
    if ($result) {
        //echo "The query executed successfully [$result].<br>";
        for ($row = 0; $row < pg_numrows($result); $row++) {
            $values = pg_fetch_array($result, $row, PGSQL_ASSOC);
            $time = $values['timeleft'];
            $today = $values['today'];
            if ($values['isrunning'] == 't')
                $running = TRUE;
            else
                $running = FALSE;
            //echo "Timeleft = $time<br>";
            //echo "Is Running = $running<br>";
        }
    } else {
        echo "The query failed with the following error:<br>";
        echo pg_errormessage($db_handle);
    }

    // Cleanup database connection
    pg_freeresult($result);
    pg_close($db_handle);

    // Got the data.  Display it.  (Need pause button?)
    // Turn the number of seconds to hh:mm:ss
    // BUGFIX: Allow negative time
    if ($time < 0 )
    {
        echo "<i>Total Remaining:</i> ~", intval($time/60), " min <br>";
    }
    else
    {
        echo "<i>Total Remaining:</i> ", gmdate("z:H:i:s", $time), "<br>";
    }
    echo "<i>Remaining Today:</i> ", gmdate("H:i:s", $today), "<br>";
    if ($running)
    {
        echo "[<b>Running</b>]<br>";
        echo "<form method=\"POST\" action=\"./stop-start.php?user_name=$user_name\">";
        echo "<input type=\"submit\" value=\"Stop\">";
    }
    else
    {
        echo "<br>";
        echo "<form method=\"POST\" action=\"./stop-start.php?user_name=$user_name\">";
        echo "<input type=\"submit\" value=\"Start\">";
    }
    echo "</form>";
    // Show pause button

} // end else (if username == '')

?>

</body>
</html>
