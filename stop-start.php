<?php
# $Id: stop-start.php,v 1.3 2014/07/06 23:25:49 jepace Exp $

$user_name = trim($_GET['user_name']);
$error = '';

if ($user_name == '')
    $error = 'UsernameRequired';

// Build the query string to be attached 
// to the redirected URL
$query_string = '?user_name=' . $user_name;

// Redirection needs absolute domain and phisical dir
$server_dir = $_SERVER['HTTP_HOST'] .
rtrim(dirname($_SERVER['PHP_SELF']), '/\\') . '/';

/* The header() function sends a HTTP message 
      The 303 code asks the server to use GET
         when redirecting to another page */
header('HTTP/1.1 303 See Other');

if ($error != '')
{
    // Back to register page
    $next_page = 'index.php';
    // Add error message to the query string
    $query_string .= '&error=' . $error;
    // This message asks the server to redirect to another
    // page
    header('Location: http://' . $server_dir . $next_page .  $query_string);
}
// No error: If Ok then go to confirmation
else
    $next_page = 'index.php';

/* Toggle the state in the database */
$db_handle = pg_connect("dbname=pfm user=pgsql");
$query = "UPDATE pfm SET isrunning = NOT isrunning WHERE login = '$user_name'";
$result = pg_exec($db_handle, $query);
pg_close($db_handle);

/*
   Here is where the PHP sql data insertion code will be
   */
// Redirect to confirmation page
header('Location: http://' . $server_dir . $next_page .
       $query_string);
?>
