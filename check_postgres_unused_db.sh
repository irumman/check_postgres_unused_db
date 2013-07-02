    #!/bin/bash
    # ========================================================================================
    # Check Postgresql Unused Database.
    # Description: Create alert base on the number of databases older than given mode,time and units for a given Postgrsql database server
    # Author: www.rummandba.com
    # This script expects psql to be in the PATH.
    #
    # Usage: ./check_postgres_unused_db [-h] [-v][ -H <host> ] [ -P <port> ] [ -U user ] [ -D dbname] [ -x <units> ]
    #                                      [-w <warn_period>] [-c <critical_period>]
    #   -H   --host       host (default 127.0.0.1)
    #   -P   --port       port (default 5432)
    #   -U   --user       database user (default postgres)
    #   -S   --password   database user password
    #   -D   --dbname     dbname to connect with postgresql (default postgres)
    #   -m   --mode       mode of time to check with current time to mark as unused (c = create, a = access, m = modified; default : a) 
    #   -t   --time       number of times after that database should be marked as unused
    #   -x   --units      units of measurement to compare (s = seconds; m = minutes; h = hours; D = days; M = months; Y = year)
    #   -w   --warning    warning threshold (default 1 )
    #   -c   --critical   critical threshold (default 3)
    # ========================================================================================



    # Nagios return codes
    STATE_OK=0
    STATE_WARNING=1
    STATE_CRITICAL=2
    STATE_UNKNOWN=3
    STATE=$STATE_OK
    
    #DB Connection    
    HOST="127.0.0.1"
    PORT=5432
    USER=postgres
    DBNAME=postgres
    PASSWORD=''
    
    #Time to compare
    TIME_MODE='a'
    TIME=1
    UNITS="D"
    
    #Number of databases
    WARNING_THRESHOLD=1
    CRITICAL_THRESHOLD=3

    
    DEBUG=0
    OUTSTR=''
    COUNT=0
    
    SQL=''
    GET_RESULT=''
    
    
    debug_print() {
      if [ "$DEBUG" -eq 1 ];
      then
        OUTPUT=$1
        echo -e "DEBUG:: "$OUTPUT >> /tmp/check_postgres_unused_db.log
      fi 
    }
    
    pg_execute_command () {
      debug_print "SQL = " $SQL
      if [ -z $PASSWORD ];
      then
         debug_print "PASSOWRD is empty"   
      else
         debug_print "PASSOWRD = $PASSOWRD"
         export PGPASSWORD=$PASSWORD   
      fi   
      debug_print "Command = psql -d $DBNAME -U $USER -Atc \"$SQL\" -h $HOST -p $PORT"
      GET_RESULT=`/usr/bin/psql -d $DBNAME -U $USER -Atc "$SQL" -h $HOST -p $PORT`
    } #pg_execute_command
    

    help_print() {
    echo "Check Postgresql Unused Database"
    echo ""
    echo "Description: Create alert base on the number of databases older than given mode,time and units for a given Postgrsql database server"
    echo "Author: www.rummandba.com"
    echo "# This script expects psql to be in the PATH."
    echo ""
    echo "Usage: ./check_postgres_least_vacuum [-h] [-v][ -H <host> ] [ -P <port> ] [ -U user ] [ -D dbname] [ -m <mode of time> ] [ -t <time value> ] [ -x <units> ] [-w <warn count>] [-c <critical count>]"
    echo " -h   --help       help"
    echo " -v   --verbose    verbose or debug mode"
    echo " -H   --host       host (default 127.0.0.1)"
    echo " -P   --port       port (default 5432)"
    echo " -U   --user       database user (default postgres)"
    echo " -S   --password   database user password"
    echo " -D   --dbname     dbname to connect with postgresql (default postgres)"
    echo " -m   --mode       mode of time to check with current time to mark as unused (c = create, a = access, m = modified; default : a)" 
    echo " -t   --time       number of times after that database should be marked as unused"
    echo " -x   --units      units of measurement to compare (s = seconds; m = minutes; h = hours; D = days; M = months; Y = year)"
    echo " -w   --warning    warning threshold; number of databases older than given mode,time and units (default 1 )"
    echo " -c   --critical   critical threshold;number of databases older than given mode,time and units (default 3 )"
    }


    # Parse parameters
    while [ $# -gt 0 ]; do
        case "$1" in
           -h | --help)
                    help_print
                    exit 0;
                    ;;                       
           -v | --verbose)
                    DEBUG=1 
                    ;;      
            -H | --host)
                    shift
                    HOST=$1
                    ;;
            -P | --port)
                    shift
                    PORT=$1
                    ;;
            -U | --user)
                    shift
                    USER=$1
                    ;;
            -D | --dbname)
                    shift
                    DBNAME=$1
                    ;;       
            -S | --password)
                    shift
                    PASSWORD=$1
                    ;;                
            -m | --mode)
                    shift
                    TIME_MODE=$1
                    ;;                            
            -t | --time)
                    shift
                    TIME=$1
                    ;;     
            -x | --unit)
                    shift
                    UNITS=$1
                    ;;                       
            -w | --warning)
                    shift
                    WARNING_THRESHOLD=$1
                    ;;
            -c | --critical)
                    shift
                    CRITICAL_THRESHOLD=$1
                     ;;
            *)  echo "Unknown argument: $1"
                exit $STATE_UNKNOWN
                ;;
            esac
    shift
    done

    debug_print  "Verbose mode is ON"
    debug_print "HOST=$HOST"
    debug_print "PORT=$PORT"
    debug_print "USER=$USER"
    debug_print "DBNAME=$DBNAME"
    debug_print "UNITS=$UNITS"
    debug_print "WARNING_THRESHOLD=$WARNING_THRESHOLD"
    debug_print "CRITICAL_THRESHOLD=$CRITICAL_THRESHOLD"


    #Check for units
    if [ $UNITS == 's' ];
    then
      let DIV=1
      UNITS="seconds"
    elif   [ $UNITS == 'm' ];
    then
      let DIV=60
      UNITS="minutes"
    elif   [ $UNITS == 'h' ];
    then
      let DIV=60*60
      UNITS="hours"
    elif   [ $UNITS == 'D' ];
    then
      let DIV=60*60*24
      UNITS="days"
    elif   [ $UNITS == 'M' ];
    then
      let DIV=60*60*24*30
      UNITS="months"
    elif   [ $UNITS == 'Y' ];
    then
      let DIV=60*60*24*30*12
      UNITS="years"
    else
      echo "!!!Invaild unit values!!!"
      exit $STATE_UNKNOWN 
    fi 
    
    #Check for time mode
    if [ $TIME_MODE == 'a' ];
    then
      TIME_MODE="atime"
      TIME_MODE_DISPLAY="accessed"
    elif   [ $TIME_MODE == 'c' ];
    then
      TIME_MODE="ctime"
      TIME_MODE_DISPLAY="created"
    elif   [ $TIME_MODE == 'm' ];
    then
      TIME_MODE="mtime"
      TIME_MODE_DISPLAY="modified"
    else
      echo "!!!Invaild time mode values!!!"
      exit $STATE_UNKNOWN 
    fi  
       
    CURRENT_DATE=`eval date +%Y-%m-%d_%H:%M:%S`
    CURRENT_DATE=`echo "$CURRENT_DATE" | sed -r 's/[_]+/ /g'`
    CURRENT_DATE_INT=`date --date="$CURRENT_DATE" +%s`
    
    CHECK_TIME=$CURRENT_DATE
    CHECK_TIME_INT=$CURRENT_DATE_INT
    debug_print "Current_date = $CHECK_TIME ($CHECK_TIME_INT)"
    
    
    debug_print "Create function check_pg_unused_db_f"
    SQL="
    CREATE OR REPLACE FUNCTION check_pg_unused_db_f(stat_type varchar, dbid int)
		RETURNS text As \$BODY\$
			import sys
			import os
			import datetime
			
			afilename = 'base/' + str(dbid)
			(mode, ino, dev, nlink, uid, gid, size, atime, mtime, ctime) = os.stat(afilename)
			if stat_type == 'atime':
			  return datetime.datetime.fromtimestamp(atime)
			elif stat_type == 'mtime':
			  return datetime.datetime.fromtimestamp(mtime)  
			elif stat_type == 'ctime':
			  afilename =  afilename + '/PG_VERSION' 
	      (mode, ino, dev, nlink, uid, gid, size, atime, mtime, ctime) = os.stat(afilename)
			  return datetime.datetime.fromtimestamp(ctime)
			else:
			  return 'UnknownVariable'    
			
		\$BODY\$ Language plpythonu;
    "
    
    debug_print $SQL
    #GET_RESULT=`psql -d $DBNAME -U $USER -Atc "$SQL" -h $HOST -p $PORT`
    pg_execute_command
    if [ $? -gt 0 ];
    then
      echo "ERROR:; can't create function at Postgresql database"
      exit $STATE_UNKNOWN
    fi 
    
    #Get dblist
    SQL="SELECT OID, datname, replace(check_pg_unused_db_f('"$TIME_MODE"', OID::int ),' ','_') as check_time FROM pg_database WHERE datallowconn and NOT datistemplate and datname NOT  IN ('postgres')"
    pg_execute_command
    GET_DB_LIST=$GET_RESULT
    if [ $? -gt 0 ];
    then
      echo "ERROR:; can't get the db list from Postgresql database"
      exit $STATE_UNKNOWN
    fi 

    
    #Drop function
    
    SQL="DROP FUNCTION check_pg_unused_db_f(stat_type varchar, dbid int)"
    pg_execute_command
    
    if [ $? -gt 0 ];
    then
      echo "ERROR:; can't drop the function at Postgresql database"
      exit $STATE_UNKNOWN
    fi 
    
    
    
    debug_print  "Database lists = $GET_DB_LIST"
    array=(${GET_DB_LIST// / })
    for i in "${!array[@]}"
    do 
        
        DB=${array[i]}
        debug_print "\nWorkiing for $DB ..."
        
        DBID=`echo $DB | cut -d '|' -f1`             
        debug_print "dbid = $DBID"
        
        DBNAME=`echo $DB | cut -d '|' -f2`             
        debug_print "dbname = $DBNAME"
        
        CHECK_TIME=`echo $DB | cut -d '|' -f3`             
        CHECK_TIME=`echo "$CHECK_TIME" | sed -r 's/[_]+/ /g'`
        debug_print "CHECK_TIME= $CHECK_TIME"
        
        CHECK_TIME_INT=`date --date="$CHECK_TIME" +%s`
        debug_print "CHECK_TIME_INT = $CHECK_TIME_INT"
        
        #Calculate date diff
        DIFF=`echo $"(( $(date --date="$CURRENT_DATE" +%s) - $(date --date="$CHECK_TIME" +%s) ))/($DIV)"|bc`
        debug_print " DIFF = $DIFF"
        
        if  [ $DIFF -ge $TIME ];
        then
          COUNT=`echo "$COUNT + 1"|bc`
          OUTSTR="$OUTSTR\n  $COUNT) Database \"$DBNAME\" last $TIME_MODE_DISPLAY on the $CHECK_TIME that is $DIFF $UNITS ago"
        fi
    done
    debug_print "$OUTSTR"
    debug_print "Count = $COUNT; Critical Threshold = $CRITICAL_THRESHOLD"    
    if [ $COUNT -ge $CRITICAL_THRESHOLD ]; 
    then
      debug_print "CRITICAL: $COUNT unused database(s) found at $HOST:$PORT that were last $TIME_MODE_DISPLAY $TIME $UNITS ago :- \n$OUTSTR"
      echo -e "CRITICAL: $COUNT unused database(s) found at $HOST:$PORT that were last $TIME_MODE_DISPLAY $TIME $UNITS ago :- \n$OUTSTR"
      exit $STATE_CRITICAL
      
    elif  [ $COUNT -ge $WARNING_THRESHOLD ]; 
    then
      debug_print "WARNING: $COUNT unused database(s) found at $HOST:$PORT that were last $TIME_MODE_DISPLAY $TIME $UNITS ago :- \n$OUTSTR"
      echo -e "WARNING: $COUNT unused database(s) found at $HOST:$PORT that were last $TIME_MODE_DISPLAY $TIME $UNITS ago :- \n$OUTSTR"
      exit $STATE_WARNING
      
    else
      debug_print "OK: No unused database found  at $HOST:$PORT that were last $TIME_MODE_DISPLAY $TIME $UNITS ago"
      echo -e "OK: No unused database found  at $HOST:$PORT that were last $TIME_MODE_DISPLAY $TIME $UNITS ago"
      exit $STATE_OK
    fi  
    
