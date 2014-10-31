<html>
<head>
    <!-- $Id: admin.php,v 1.6 2014/09/09 00:01:14 jepace Exp $ -->
    <title> PFMonster </title>
    <meta http-equiv="refresh" content="60">
    <meta name="viewport" content="width=device-width;
        initial-scale=1.0; maximum-scale=1.0; user-scalable=0;"/>
</head>

<body>
    <h3> PFMonster Admin Interface </h3>
 
<style>
table,th,td
{
border:1px solid black;
}
</style>

    <table>
    <tr> 
        <th> User </th>
        <th> Total Time </th>
        <th> Today </th>
        <th> Running? </th>
        <th> Last Use </th>
    </tr>
<?php

    // Database check
    $db_handle = pg_pconnect("dbname=pfm user=pgsql");   
    $query = "SELECT login, timeleft, today, isrunning, last_login FROM pfm ORDER BY login ASC";
    $result = pg_exec($db_handle, $query);
    if ($result) {
        //echo "The query executed successfully [$result].<br>";
        for ($row = 0; $row < pg_numrows($result); $row++) {
            echo "<tr>";
            $values = pg_fetch_array($result, $row, PGSQL_ASSOC);
            $user = $values['login'];
            $time = $values['timeleft'];
            $today = $values['today'];
            $lasttime = $values['last_login'];
            if ($values['isrunning'] == 't')
                $running = "True";
            else
                $running = "False";
            echo "<td> $user </td>";

            // BUG FIX: Allow negative time
            if ($time < 0 )
            {
                echo "<td> ~ ", intval( $time/60 ), " min </td>";
            }
            else
            {
                echo "<td>", gmdate("z:H:i:s", $time), "</td>";
            }

            echo "<td>", gmdate("H:i:s", $today), "</td>";
            echo "<td> $running </td>";
            echo "<td> $lasttime </td>";
            echo "</tr>";
        }
        echo "</table>";
    } else {
        echo "The query failed with the following error:<br>";
        echo pg_errormessage($db_handle);
    }

    // Cleanup database connection
    pg_freeresult($result);
    pg_close($db_handle);
?>

</body>
</html>
