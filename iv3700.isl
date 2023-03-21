// ImageVault 3700 Interface (2.2)      
// -----------------------------------------------------
//
//	ImageVault Sim
//
//	Micros 3700
//
//	8/17/2010
//	Version 2.2 3700
//
//	Author: Keven Beach, Beyond POS, Inc.
//
// -----------------------------------------------------
//	This SIM will updates a custom database table with
//	transaction information.
//	And the IV3700 service sends it on to the cameras.
//
//
// The IV3700_user.dat file contains the following, one line each
//	USE_BPSQL | USE_MICROS
//	PRE_32 | POST_32
//	Database User (e.g. "custom"
//	Encrypted Database Password (e.g. "2f33b421"
//
// This file should be in CAL on the ws4, or in ....\etc\ImageVault on workstations w/hard drives
//	and the server.
//
// Version 1.3 
//	Added messages of all check detail on check close, so that lookups will work
// 	more nicely.
//
//	Changed "EC" to "EVOID"
//
// Version 1.4 
//	Added text configuration for some items, and added more detail at service totoal/tender
//	to be closer to the check.
//	This means we have a new table which is read at read_params.
// Version 1.4a 
//	Moda to the server and config.  Also added a line into the iv3700_user.dat file, so
//	this version reads teh user and pwd from different rows int he file.
//
// Version 1.4b 
//	Added vars to allow it to only read param file and db params when there are
//	params that are not set.  This should speed up normal operation, but may 
//	require reboot of UWS to refresh changed parameters.
//
// Version 1.4c 
// 	New Odbc init process.  Now, inits/ connects when needed, bt only closes the conn when
// 	transaction is over/signout/clockin/out/init functions, etc.  During trans, it should
//	stay open.
// Ver 1.5
//	Radicall stuff.  Now send all inserts as 1 "db" call.  Most functions now dont do 
//	db lookups, like emp/rvc/tables.
//	Params now stored in local etc folder in iv3700_params.txt.
// Ver 1.5a 
//	Fixed issue with myrvcname being too long  for the formatP{
//	Fixed issue with string overflow on large queries.
//
// 	Fixed Change Due name on direct overtender...
//
// Ver 1.5b 
//	Re-added close_odbc after every function because in Res 4.3 the odbc drivers dont appear to be 
// 	submitting the sql statements until the Close function happens.
//
// Ver 1.5d 
//	Corrected variable name problem with service charges.
//
// Ver 1.5e 
//	Now always check sqlGetLastErr on sqlExec ...
//	Chaneg checks for hDLL to check for <> 0 since they can be - on WS4 models...
//
// Ver 1.6 
//	Summary Lines added:
//		Nosale, Trans Cancel, Service Total, etc.
//		This requires new table iagevault_check_flags to store the "has_ec" 0/1.  
//		
//	Fixed clockin/out so that micros cards can be used.
// Ver 1.6a
//	Added update_check_flags to event TNDR so that we get ECs when it is never service totalled.
//	Fixed break issue in update 

// Ver 1.6c
//	Added Name 2 to menu item output
//	Added Menu Level to output.
//
//	<<MIDEF00000000M00000000R00000000L is now sent and the server looks up
//	the name (based on item M) and the level name (based on rvc R and level L).
//	Option added to enable / disable level and name 2 at servic level
//
// Ver 1.6d
//	If EMP Prefix is empty, no summary messages will be sent...
//
// Ver 1.6e
//	mods - added event idle_no_trans that fires 3 seconds after final tender, so that
// 	it wont interfere w/other final tender sms (svc2)

// Ver 2.0
//	Split off a 9700 version that is totally separate.
//      Added split/transfer notices
//	Minor bug fixes
//      Added autograd to final tender line
// Ver 2.1
//	Added checks for standalone mode and backupserver mode.
//      Now, it just skips processing anything if either of these are set.
//
// Ver2.2
//	Res5 support fixed by adding DBName.  Also changes the config file.
//	NoSale was fixed.



SetSignOnLeft
UseISLTimeOuts
RetainGlobalVar

// 1 = Always read odbc_parasm file
// 0 = Only read it when the DBUser/Pwd are empty.
var READ_PFILE_ALWAYS :N1 = 0
var READ_PARAMS_ALWAYS :N1 = 0


var HAS_CHGTIP : N1
var HAS_INREOPEN : N1
var HAS_INEDIT : N1
var HAS_VOIDSTATUS : N1
var USE_BPSQL : N1
var PRE_32    : N1 

var EC_TEXT :A10 = "EVOID"
var VOID_TEXT :A10 = "VOID"

// ODBC Stuff
var LICENSE 		: A80 = "DEMO"
var BPSQL_Init 		: A10 = "1"
var BPSQL_Query 	: A10 = "2"
var BPSQL_Fetch 	: A10 = "3"
var BPSQL_Close 	: A10 = "4"
var hDLL 		: N12
var DBName		: A128
var DBUser		: A128
var DBPwd		: A128
var DBPwdEnc		: A128
var G_DidInit 		: N1
var G_CurrentEmp	: N9
var G_CurrentEID	: A40
var G_CurrentELname	: A40
var G_CurrentEFname	: A40
var G_CurrentChkname	: A40
var G_VTYPE		: A10
var DLL_GOT_FIRST	: N9
var constatus		: N9
var hFS			: A10
var G_HAS_EC 		: N1
var G_HAS_SVC2		: N1 = 1
var G_SPLIT_TYPE	: N1
var G_SPLIT_EMP 	: N9

var G_sx_date_time : A64 
    

// var GMsgSeparator : A50 = "---------------------------------------"
var GMsgSeparator : A50 = "  "

// UWS List
//
var Nws 	: N9
var WsList[100] : N9

// Used Inquire Numbers
var CLOCK_INOUT_INQ : N3 = 1
var SIM_NO_SALE_INQ : N3 = 2
var XFER_CHECK_NUM_INQ : N3 = 3
var XFER_CHECK_SLU_INQ : N3 = 6
var XFER_CHECK_ID_INQ : N3 = 7
var XFER_CHECK_TABLE_INQ : N3 = 8
var SPLIT_CHECK_INQ : N3 = 4
var BLOCK_XFER_CHECK_INQ : N3 = 5

var INQ_T20 : N9 = 20
var INQ_T11 : N9 = 11
var INQ_T12 : N9 = 12
var INQ_T13 : N9 = 13
var INQ_T14 : N9 = 14
var INQ_T15 : N9 = 15
var INQ_T16 : N9 = 16
var INQ_T17 : N9 = 17
var INQ_T18 : N9 = 18
var INQ_T19 : N9 = 19

// Tender numbers that match INQ 10 - 19
var TMED_INQ_20 : N9
var TMED_INQ_11 : N9
var TMED_INQ_12 : N9
var TMED_INQ_13 : N9
var TMED_INQ_14 : N9
var TMED_INQ_15 : N9
var TMED_INQ_16 : N9
var TMED_INQ_17 : N9
var TMED_INQ_18 : N9
var TMED_INQ_19 : N9

// Text Itmes
var TXT_SUBTTL : A80
var TXT_TAXTTL : A80
var TXT_DSCTTL : A80
var TXT_SVCTTL : A80
var TXT_PMTTTL : A80
var TXT_SI[8] : A80
var TXT_TAX[8] : A80
var TXT_COVERS : A80
var TXT_TABLE : A80
var TXT_CHECK : A80
var TXT_CHANGEDUE : A80
var TXT_CHGTIP : A80
var TXT_AUTOGRAT : A80
var TXT_SPLIT_CHECK : A80
var TXT_ADD_CHECK : A80
var TXT_XFER_CHECK : A80

// Summary Line Items
// These are text strings to flag stuff for search:
var STXT_EMP_PRE : A80				// EN_Chuch = EN_
var STXT_VOID : A80
var STXT_EVOID : A80
var STXT_CANCEL : A80
var STXT_NOSALE : A80
var STXT_DTL_NAMES[99] : A80
var STXT_DTL_TAGS[99] : A80
var N_STXT_DTLS : N9
var MAX_MSG_LEN : N9 = 64


// Last menu item added to the check
var MAX_DTL :N3 = 700
var gx : N9
var N_MI_NEW : N9
var N_MI_VOID : N9

// This is a list of the current round shit
// This will contain current round entries.
// Cleared at Service Total.
var NG_DTL : N9 
var GLastExtraDtl : N9
var G_DTL_SENT[MAX_DTL] : A9		// yes/no
var G_DTL_DTL[MAX_DTL] : A9		// Detail number
var G_DTL_TYPE[MAX_DTL] : A5	// Type
var G_DTL_OBJ[MAX_DTL] : N9		// OBJ
var G_DTL_MLVL[MAX_DTL] : N9		// menu level
var G_DTL_NAME[MAX_DTL] : A40	// Name
var G_DTL_TTL[MAX_DTL] : $12	// Amount
var G_DTL_QTY[MAX_DTL] : $12	// QTY
var G_DTL_CT_TTL[MAX_DTL] : $12	// Charge Tip Ttl


var im_reopen : N1 = 0
var im_edit : N1 = 0

// Micros Constants....
var CLK_IN_KEY : N9 = 655368
var BC_TBL_KEY : N9 = 327682	
var BC_ID_KEY : N9 = 327683	
var NO_SALE_KEY : N9 =655362

// These might be overridden by params, or macro.
// Lets start at 0, and then we will
// populate the defaults in read_param
var SPLIT_CHECK_KEY : N9 = 393280

// Add/Xfer key numbers are null
var ADD_XFER_NUM_KEY_TYPE : N9 = 13
var ADD_XFER_TBL_KEY_TYPE : N9 = 14
var ADD_XFER_ID_KEY_TYPE : N9 = 15
var ADD_XFER_SLU_KEY_TYPE : N9 = 21

// block xfer type = 1
var BLOCK_XFER_KEY : N9 = 393220

// This is to allow time for the DB to post the stuff after the event final_tender
event idle_no_trans
   @IDLE_SECONDS = 0

   call check_server_mode
   call do_final_tender

   // Turn ourselves back off.  Final Tender turns us on...
   G_SPLIT_TYPE = 0
   G_SPLIT_EMP = 0
   G_sx_date_time = ""

endevent

// Tips Paid keys
event inq : 20
   call check_server_mode

   var mydata : A40 = ""
   var myamt :$12 = 0

   call get_amount(myamt)
   call do_tender_inq (20, myamt)
   call close_odbc
endevent

event inq : 21
   call check_server_mode

   var mydata : A40 = ""
   var myamt :$12 = 0

   call get_amount(myamt)
   call do_tender_inq (21, myamt)
   call close_odbc
endevent
event inq : 22
   call check_server_mode

   var mydata : A40 = ""
   var myamt :$12 = 0

   call get_amount(myamt)
   call do_tender_inq (22, myamt)
   call close_odbc
endevent
event inq : 23
   call check_server_mode

   var mydata : A40 = ""
   var myamt :$12 = 0

   call get_amount(myamt)
   call do_tender_inq (23, myamt)
   call close_odbc
endevent
event inq : 24
   call check_server_mode

   var mydata : A40 = ""
   var myamt :$12 = 0

   call get_amount(myamt)
   call do_tender_inq (24, myamt)
   call close_odbc
endevent
event inq : 25
   call check_server_mode

   var mydata : A40 = ""
   var myamt :$12 = 0

   call get_amount(myamt)
   call do_tender_inq (25, myamt)
   call close_odbc
endevent

sub do_tender_inq (var mytmedidx : N9, var myamount : $12) 
   // Tips paid and media loan/pickup keys.
   var atmp : A256 = ""
   var mylname : A80 = ""
   var myfname : A80 = ""
   var mychkname : A80 = ""
   var myrvcname : A80 = ""
   var mytmedname : A80 = ""
   var myrvcseq : A80 = ""
   var mytable : A80 = ""
   var mytmed : N9 = 0
   var dti : N9 = 0
   var iv_msg[20] : A128
   var iv_stat : A1024 = ""
   var iv_results : A1024 = ""

   call check_uws 
   call clear_current_round

   // @VOIDSTATUS isnt in all versions, so dont use it.
   // These tenders will never be on the check, so it will
   // either be positive or negative.  Just report the
   // amounts.
   call read_inq_tmed (mytmedidx, iv_stat, mytmed, mytmedname)
   if mytmed = 0
      errormessage "Undefined Inquire Based Tender: ", mytmedidx
      exitcancel
   endif
   format atmp as mytmedname  
   if HAS_VOIDSTATUS = 1
      if @VOIDSTATUS = 1
         format atmp as "VOID ", mytmedname  
      endif
   endif
         
   call read_ename_obj (@TREMP, iv_stat, mylname, myfname, mychkname)
   call read_rvcname (iv_stat, myrvcname, myrvcseq)

   call init_odbc (iv_stat)
   if iv_stat <= 0
      errormessage "ODBC Init Error: ", iv_stat
      return
   endif

   dti = 1
   format iv_msg[dti] as "Tender Non Payment"{<20}
   	// call send_msg (1, 1, iv_msg, iv_stat, iv_results)
   dti = dti + 1
   format iv_msg[dti] as myrvcname
   	// call send_msg (0, 1, iv_msg, iv_stat, iv_results)
   dti = dti + 1
   format iv_msg[dti] as "Emp: ", @TREMP, " ", mylname, ", ", myfname
   	// call send_msg (0, 1, iv_msg, iv_stat, iv_results)
   
   format atmp as  @MONTH{02}, "/", @DAY{02}, "/", @YEAR{02}, \
                    @HOUR{02}, ":", @MINUTE{02}, ":", @SECOND{02}
   dti = dti + 1
   format iv_msg[dti] as atmp
   call send_msg (0, 1, iv_msg[], dti, iv_stat, iv_results)
		 
   // call close_odbc
   call close_odbc

   // Load the tender we should call...
   loadkybdmacro makekeys(myamt), key(10,mytmed)


 
endsub
event init

   @IDLE_SECONDS = 0
   call check_server_mode
   call check_uws 
   call clear_current_round
   // if G_HAS_SVC2 <= 0
      call do_wsup
      call close_odbc
   // endif
   G_HAS_EC = 0
   G_SPLIT_TYPE = 0
   G_SPLIT_EMP = 0
   G_sx_date_time = ""

endevent
event exit
   call check_server_mode
   call check_uws 
   call clear_current_round
   call do_wsdown
   call close_odbc
   G_HAS_EC = 0
   G_SPLIT_TYPE = 0
   G_SPLIT_EMP = 0
   G_sx_date_time = ""

endevent
event trans_cncl
   call check_server_mode
   call check_uws 
   call clear_current_round
   call do_trans_cncl
   call close_odbc
   G_HAS_EC = 0
   call do_split_xfer 
endevent

event clockin
   call check_server_mode
   call check_uws 
   call clear_current_round
   call do_clock_in
   call close_odbc
   G_HAS_EC = 0
   G_SPLIT_TYPE = 0
   G_SPLIT_EMP = 0
   G_sx_date_time = ""
endevent
event clockout
   call check_server_mode
   call check_uws 
   call do_clock_out
   call close_odbc
   G_HAS_EC = 0
   G_SPLIT_TYPE = 0
   G_SPLIT_EMP = 0
   G_sx_date_time = ""
endevent

event inq : SPLIT_CHECK_INQ
   // SPLIT = 1
   // XFER = 2
   // Block XFER = 3
   G_SPLIT_TYPE = 1
   G_SPLIT_EMP = @TREMP

   // date time flagged now, and sent, so that the service can tell
   // what the earliest trx should be...
   var nyear : N9 = @YEAR + 2000
   format G_sx_date_time as nyear{04}, "-", @month{02}, "-", @day{02}, " ", \
                            @hour{02}, ":", @minute{02}, ":", @second{02}

   loadkybdmacro key (1, SPLIT_CHECK_KEY)

endevent

//

event inq : XFER_CHECK_ID_INQ
   G_SPLIT_TYPE = 2
   G_SPLIT_EMP = @TREMP

   // date time flagged now, and sent, so that the service can tell
   // what the earliest trx should be...
   var nyear : N9 = @YEAR + 2000
   format G_sx_date_time as nyear{04}, "-", @month{02}, "-", @day{02}, " ", \
                            @hour{02}, ":", @minute{02}, ":", @second{02}
      
   loadkybdmacro key (ADD_XFER_ID_KEY_TYPE,0)
   
endevent
event inq : XFER_CHECK_NUM_INQ
   G_SPLIT_TYPE = 2
   G_SPLIT_EMP = @TREMP

   // date time flagged now, and sent, so that the service can tell
   // what the earliest trx should be...
   var nyear : N9 = @YEAR + 2000
   format G_sx_date_time as nyear{04}, "-", @month{02}, "-", @day{02}, " ", \
                            @hour{02}, ":", @minute{02}, ":", @second{02}
      
   loadkybdmacro key (ADD_XFER_NUM_KEY_TYPE,0)
   
endevent
event inq : XFER_CHECK_TABLE_INQ
   G_SPLIT_TYPE = 2
   G_SPLIT_EMP = @TREMP

   // date time flagged now, and sent, so that the service can tell
   // what the earliest trx should be...
   var nyear : N9 = @YEAR + 2000
   format G_sx_date_time as nyear{04}, "-", @month{02}, "-", @day{02}, " ", \
                            @hour{02}, ":", @minute{02}, ":", @second{02}
      
   loadkybdmacro key (ADD_XFER_TBL_KEY_TYPE,0)
   
endevent
event inq : XFER_CHECK_SLU_INQ
   G_SPLIT_TYPE = 2
   G_SPLIT_EMP = @TREMP

   // date time flagged now, and sent, so that the service can tell
   // what the earliest trx should be...
   var nyear : N9 = @YEAR + 2000
   format G_sx_date_time as nyear{04}, "-", @month{02}, "-", @day{02}, " ", \
                            @hour{02}, ":", @minute{02}, ":", @second{02}
      
   loadkybdmacro key (ADD_XFER_SLU_KEY_TYPE,0)
   
endevent
event inq : BLOCK_XFER_CHECK_INQ
   // This one gets processed in final_tender, because it has to go from the idle-no-trans
   // no svcttl event is triggerred on this one...
   
   // SPLIT = 1
   // XFER = 2
   // Block XFER = 3
   G_SPLIT_TYPE = 3
   G_SPLIT_EMP = @TREMP

   // date time flagged now, and sent, so that the service can tell
   // what the earliest trx should be...
   var nyear : N9 = @YEAR + 2000
   format G_sx_date_time as nyear{04}, "-", @month{02}, "-", @day{02}, " ", \
                            @hour{02}, ":", @minute{02}, ":", @second{02}

   loadkybdmacro key (1, BLOCK_XFER_KEY)
   @IDLE_SECONDS = 3

endevent

sub do_split_xfer
   //errormessage "split/xfer"

   if G_SPLIT_TYPE <= 0
      return
   endif

   var atmp : A256 = ""
   var mylname : A80 = ""
   var myfname : A80 = ""
   var mychkname : A80 = ""
   var myrvcname : A80 = ""
   var myrvcseq : A80 = ""
   var mytable : A80 = ""
   var sxi : N9 
   var sx_msg[10] : A128
   var sx_stat : A256 = ""
   var sx_results : A4096 = ""

   // G_HAS_EC = 0
   call check_uws 

   if @CKNUM > 0
      call save_current_round 
   endif

   call read_ename_obj (@TREMP, sx_stat, mylname, myfname, mychkname)
   call read_rvcname (sx_stat, myrvcname, myrvcseq)
   call read_table (myrvcseq, sx_stat, mytable)

   call init_odbc (sx_stat)
   if sx_stat <= 0
      errormessage "ODBC Init Error: ", sx_stat
      return
   endif

   cleararray sx_msg
   sxi = 1

   if G_SPLIT_EMP <= 0
      G_SPLIT_EMP = @TREMP
   endif

   if G_SPLIT_TYPE = 1
      format sx_msg[sxi] as "MSG_SPLIT_CHECK|", G_SPLIT_EMP, "|", @RVC, "|", @CKNUM, "|", G_sx_date_time
   elseif G_SPLIT_TYPE = 2
      format sx_msg[sxi] as "MSG_XFER_CHECK|", G_SPLIT_EMP, "|", @RVC, "|", @CKNUM, "|", G_sx_date_time
   elseif G_SPLIT_TYPE = 3
      format sx_msg[sxi] as "MSG_BLOCK_XFER_CHECK|", G_SPLIT_EMP, "|", @RVC, "|", @CKNUM, "|", G_sx_date_time
   endif

   // Notify the service.  It will watch for the add/xfer in a little while....

   call send_msg (0, 1, sx_msg[], sxi, sx_stat, sx_results)
		 
   call close_odbc

   G_SPLIT_TYPE = 0
   G_SPLIT_EMP = 0
   G_sx_date_time = ""

endsub


event inq : CLOCK_INOUT_INQ
   var ci_tmp : A128 = ""
   
   if @TREMP <> 0
      errormessage "Sign Out First"
      exitcancel
   endif

   G_HAS_EC = 0
   call check_uws 
   call clear_current_round
   // This sets the employee ID, then loads the micros funtion.
   var mykey : Key
   var mydata : A256 = ""
   var myid : A80 

   myid = 0
   // Match the micros prompt, so no one knows the difference....
   inputkey mykey, mydata, "Clock In/Out, Enter ID Number"
   myid = trim(mydata)
   if myid = ""
      exitcancel
   endif
   if mid(myid, 1, 1) = ";"
      ci_tmp = mid(myid, 2, len(myid))
      myid = trim(ci_tmp)
   endif
   
   G_CurrentEID = myid

   loadkybdmacro key (1, CLK_IN_KEY), makekeys (myid), @KEY_ENTER

   call close_odbc

endevent

event signin
   // Always read params at sign in

   call check_server_mode
   call read_text_params 
   call check_uws 

   call clear_current_round

   call do_signin
   G_HAS_EC = 0
endevent
event signout
   call check_server_mode
   call check_uws 
   call do_signout
   G_HAS_EC = 0

endevent

event tndr
   call check_server_mode
   call check_uws 
   call do_tender
endevent
event tndr_void 
   call check_server_mode
   call check_uws 
   G_VTYPE = VOID_TEXT
   call check_current_round
endevent
event tndr_error_correct_items
   call check_server_mode
   call check_uws 
   G_VTYPE = EC_TEXT
   G_HAS_EC = 1
   call check_current_round
endevent

event begin_check
   var atmp : A256 = ""
   var mylname : A80 = ""
   var myfname : A80 = ""
   var mychkname : A80 = ""
   var myrvcname : A80 = ""
   var myrvcseq : A80 = ""
   var mytable : A80 = ""
   var iv_msg[20] : A128 
   var iv_stat : A1024 = ""
   var iv_results : A1024 = ""
   var imi : N9 = 0

   G_HAS_EC = 0
   call check_server_mode
   call check_uws 
   call save_current_round 

   call read_ename_obj (@TREMP, iv_stat, mylname, myfname, mychkname)
   call read_rvcname (iv_stat, myrvcname, myrvcseq)
   call read_table (myrvcseq, iv_stat, mytable)

   call init_odbc (iv_stat)
   if iv_stat <= 0
      errormessage "ODBC Init Error: ", iv_stat
      return
   endif

   cleararray iv_msg
   imi=1   
   format iv_msg[imi] as "Begin Check:"{<20}, TXT_CHECK, " ", @CKNUM, " ", @CKID
      // call send_msg (2, 1, iv_msg, iv_stat, iv_results)
   imi = imi + 1
   // format iv_msg[imi] as myrvcname{<12}, TXT_TABLE, " ", mytable, "/", @GRPNUM
   format iv_msg[imi] as myrvcname,"   ", TXT_TABLE, " ", mytable, "/", @GRPNUM
      // call send_msg (0, 1, iv_msg, iv_stat, iv_results)
   imi = imi + 1
   format iv_msg[imi] as "Emp: ", @TREMP, " ", mylname, ", ", myfname
      // call send_msg (0, 1, iv_msg, iv_stat, iv_results)
   
   imi = imi + 1
   format atmp as @Chk_Open_Time
   format iv_msg[imi] as atmp
   call send_msg (0, 1, iv_msg[], imi, iv_stat, iv_results)
		 
   call close_odbc
  

//      call csg_list_menu(n_read, choice, lines[], title, use_keys)
//  ref list[]

endevent

event pickup_check
   var atmp : A256 = ""
   var mylname : A80 = ""
   var myfname : A80 = ""
   var mychkname : A80 = ""
   var myrvcname : A80 = ""
   var myrvcseq : A80 = ""
   var mytable : A80 = ""
   var pci : N9 = 0
   var iv_msg[20] : A128
   var iv_stat : A1024 = ""
   var iv_results : A1024 = ""

   G_SPLIT_TYPE = 0
   G_SPLIT_EMP = 0
   G_sx_date_time = ""
   G_HAS_EC = 0
   call check_server_mode
   call check_uws 
   call save_current_round
   call get_pickup_status
   
   call read_ename_obj (@TREMP, iv_stat, mylname, myfname, mychkname)
   call read_rvcname (iv_stat, myrvcname, myrvcseq)
   call read_table (myrvcseq, iv_stat, mytable)

   call init_odbc (iv_stat)
   if iv_stat <= 0
      errormessage "ODBC Init Error: ", iv_stat
      return
   endif

   pci = 0
   if im_reopen
      // format iv_msg as "Reopen Check:"{<20}, @CKNUM, " ", @CKID
      pci = pci + 1
      format iv_msg[pci] as "Reopen Check:"{<20}, TXT_CHECK, " ",@CKNUM, " ", @CKID
      // call send_msg (2, 1, iv_msg, iv_stat, iv_results)
   elseif im_edit
      // format iv_msg as "Adjust Check: "{<20}, @CKNUM, " ", @CKID
      pci = pci + 1
      format iv_msg[pci] as "Adjust Check: "{<20}, TXT_CHECK, " ", @CKNUM, " ", @CKID
      // call send_msg (0, 1, iv_msg, iv_stat, iv_results)
   else
      // format iv_msg as "Pickup Check: "{<20}, @CKNUM, " ", @CKID
      pci = pci + 1
      format iv_msg[pci] as "Pickup Check: "{<20}, TXT_CHECK, " ", @CKNUM, " ", @CKID
      // call send_msg (0, 1, iv_msg, iv_stat, iv_results)
   endif
   // format iv_msg as myrvcname{<12}, " Table: ", mytable
   pci = pci + 1
   format iv_msg[pci] as myrvcname,"   ", TXT_TABLE, " ", mytable, "/", @GRPNUM
   // call send_msg (0, 1, iv_msg, iv_stat, iv_results)
   pci = pci + 1
   format iv_msg[pci] as "Emp: ", @TREMP, " ", mylname, ", ", myfname
   // call send_msg (0, 1, iv_msg, iv_stat, iv_results)
   
   format atmp as @Chk_Open_Time
   pci = pci + 1
   format iv_msg[pci] as atmp
   call send_msg (0, 1, iv_msg[],pci,  iv_stat, iv_results)
		 
   call close_odbc
endevent

event final_tender
   var fti : N9 = 0
   var atmp : A1024 = ""
   var mylname : A80 = ""
   var myminame : A128 = ""
   var myfname : A80 = ""
   var mychkname : A80 = ""
   var myrvcname : A80 = ""
   var myrvcseq : A80 = ""
   var mytable : A80 = ""
   var ftmi : N9 = 0
   var iv_msg[2000] : A128
   var iv_stat : A1024 = ""
   var iv_results : A1024 = ""
   var ttl_si : $12 
   var ttl_tax : $12 
   var ttl_tmed : $12 
 
   // ------------------------------------------------------------------------------
   // Sample of closed check jrnl print...
   // ------------------------------------------------------------------------------

   //   Tbl 103/1   Chk 1937       Gst 0
   //   1 Kramer                  SERVER
   //   CE:      1 CC:      0 TC:      0
   //   Trn 4154        Nov08'07 11:50AM
   //   --------------------------------
   //       Eat In      
   //     1 Adult Buffet         7.95
   //       Charge Tip           0.26
   //       Traveler Chk        10.00
   //       Subtotal             7.95
   //       Tax                  0.60
   //       Service Chrg         0.26
   //       15pct Grat.          1.19
   //       Payment             10.00
   //   
   //       Fd Tax Coll          0.60
   //   ================================

   // ------------------------------------------------------------------------------
   
   // errormessage "FINAL_TNDR"
   call check_server_mode
   call check_uws 
   call clear_current_round
   call read_ename_obj (@TREMP, iv_stat, mylname, myfname, mychkname)
   call read_rvcname (iv_stat, myrvcname, myrvcseq)
   call read_table (myrvcseq, iv_stat, mytable)

   // Stuff for the header...
   ftmi = 1
   format iv_msg[ftmi] as "Check Close:"{<20}, TXT_CHECK," ", @CKNUM, " ", @CKID
   	//call send_msg (0, 1, iv_msg, iv_stat, iv_results)
   ftmi = ftmi + 1
   format iv_msg[ftmi] as TXT_TABLE," ", mytable, "/", @GRPNUM, "   "
   ftmi = ftmi + 1
   format iv_msg[ftmi] as TXT_CHECK," ", @CKNUM, "   "
   ftmi = ftmi + 1
   format iv_msg[ftmi] as TXT_COVERS, " ", @GST, "   "
   	//call send_msg (0, 1, iv_msg, iv_stat, iv_results)
   ftmi = ftmi + 1
   format iv_msg[ftmi] as @TREMP, " ", mylname
   	//call send_msg (0, 1, iv_msg, iv_stat, iv_results)
   
   // Send all the details ...
   ttl_tmed = 0
   for fti=1 to @NUMDTLT
         if @DTL_TYPE[fti] = "M"
             ftmi = ftmi + 1
             call set_dtl_name (@DTL_OBJECT[fti], @DTL_MLVL[fti], @RVC, myminame)
             format iv_msg[ftmi] as @DTL_QTY[fti]{<4}, myminame{<30}, @DTL_TTL[fti]{>12}
	     // errormessage fti, ":", @DTL_QTY[fti],":", @DTL_NAME[fti]{<20}, ":",@DTL_TTL[fti]
             	//call send_msg (0, 1, iv_msg, iv_stat, iv_results)
	 endif
         if @DTL_TYPE[fti] = "S"
             ftmi = ftmi + 1
             format iv_msg[ftmi] as @DTL_QTY[fti]{<4}, @DTL_NAME[fti]{<20}, @DTL_TTL[fti]{>12}
	     // errormessage fti, ":", @DTL_QTY[fti],":", @DTL_NAME[fti]{<20}, ":",@DTL_TTL[fti]
             	//call send_msg (0, 1, iv_msg, iv_stat, iv_results)
	 endif
         if @DTL_TYPE[fti] = "T" OR @DTL_TYPE[fti] = "D" OR @DTL_TYPE[fti] = "R"
             ftmi = ftmi + 1
             format iv_msg[ftmi] as @DTL_NAME[fti]{<20}, @DTL_TTL[fti]{>12}
             	//call send_msg (0, 1, iv_msg, iv_stat, iv_results)
	 endif
         if @DTL_TYPE[fti] = "T"
	    ttl_tmed = ttl_tmed +  @DTL_TTL[fti]
	 endif
   endfor

   ttl_si = 0
   ttl_tax = 0
   for fti=1 to 8
      ttl_si = ttl_si + @SI[fti]
      ttl_tax = ttl_tax + @TAX[fti]
   endfor

   ftmi = ftmi + 1
   format iv_msg[ftmi] as TXT_SUBTTL{<20}, ttl_si
   	//call send_msg (0, 1, iv_msg, iv_stat, iv_results)
   ftmi = ftmi + 1
   format iv_msg[ftmi] as TXT_TAXTTL{<20}, ttl_tax
   	//call send_msg (0, 1, iv_msg, iv_stat, iv_results)
   ftmi = ftmi + 1
   format iv_msg[ftmi] as TXT_DSCTTL{<20}, @DSC
   	//call send_msg (0, 1, iv_msg, iv_stat, iv_results)
   ftmi = ftmi + 1
   format iv_msg[ftmi] as TXT_SVCTTL{<20}, @SVC
   	//call send_msg (0, 1, iv_msg, iv_stat, iv_results)
   ftmi = ftmi + 1
   format iv_msg[ftmi] as TXT_PMTTTL{<20}, ttl_tmed
   	//call send_msg (0, 1, iv_msg, iv_stat, iv_results)

   // Itemizers and Taxes
   for fti=1 to 8
      if @SI[fti] <> 0
         ftmi = ftmi + 1
         format iv_msg[ftmi] as TXT_SI[fti]{<20}, @SI[fti]
         	//call send_msg (0, 1, iv_msg, iv_stat, iv_results)
      endif
      if @TAX[fti] <> 0
         ftmi = ftmi + 1
         format iv_msg[ftmi] as TXT_TAX[fti]{<20}, @TAX[fti]
         	//call send_msg (0, 1, iv_msg, iv_stat, iv_results)
      endif
   endfor
 
   // format iv_msg as "Close Check:"{<20}, @CKNUM, " ", @CKID
   ftmi = ftmi + 1
   format iv_msg[ftmi] as "Close Check:"{<20}, TXT_CHECK, " ", @CKNUM, " ", @CKID

   if len(trim(STXT_EMP_PRE)) > 0
      call get_sum_tags (atmp, 1) 
      // if len(atmp) > 0
      ftmi = ftmi + 1
      format iv_msg[ftmi] as STXT_EMP_PRE, @TREMP_CHKNAME, " ", atmp, " ",ttl_tmed 
      if len(iv_msg[ftmi]) > MAX_MSG_LEN
         errormessage "Trunc: ", iv_msg[ftmi]
         atmp = mid(iv_msg[ftmi], 1, MAX_MSG_LEN)
         iv_msg[ftmi] = atmp
      endif
   endif

   var fn : N9 = 0
   var maxftmi : N9 = ftmi
   var myfile : A256 = ""
   format myfile as "iv_", @WSID, ".txt"
   fopen fn, myfile, WRITE
   if fn <= 0
      errormessage "Error writing tmp imagevault file"
      errormessage myfile
      exitcontinue
   endif
   
   for ftmi = 1 to maxftmi
      fwriteln fn, iv_msg[ftmi]
   endfor
   
   fclose fn
   
   @IDLE_SECONDS = 3

endevent

sub do_final_tender

   var fti : N9 = 0
   var atmp : A1024 = ""
   var mylname : A80 = ""
   var myminame : A128 = ""
   var myfname : A80 = ""
   var mychkname : A80 = ""
   var myrvcname : A80 = ""
   var myrvcseq : A80 = ""
   var mytable : A80 = ""
   var ftmi : N9 = 0
   var iv_msg[2000] : A128
   var iv_stat : A1024 = ""
   var iv_results : A1024 = ""
   var ttl_si : $12 
   var ttl_tax : $12 
   var ttl_tmed : $12 

   @IDLE_SECONDS = 0

   // this return immediately if no xfers/splits (Block) to send.
   //
   //errormessage "Here"
   call do_split_xfer


   // --------------------------------------------------------------------
   var fn : N9 = 0
   var myfile : A256 = ""
   format myfile as "iv_", @WSID, ".txt"
   fopen fn, myfile, READ
   if fn <= 0
      // Dont error, in case we are not actualy in final tender...

      // errormessage "Error reading tmp imagevault file"
      // errormessage myfile
      exitcontinue
   endif
   
   ftmi = 0
   while not feof( fn )
      ftmi = ftmi + 1
      freadln fn, iv_msg[ftmi]
      //errormessage ftmi,": ", iv_msg[ftmi]
   endwhile
   
   fclose fn
   fopen fn, myfile, WRITE
   fclose fn

   // --------------------------------------------------------------------

   call init_odbc (iv_stat)
   if iv_stat <= 0
      errormessage "ODBC Init Error: ", iv_stat
      return
   endif

   call send_msg (0, 1, iv_msg[], ftmi, iv_stat, iv_results)
   if G_HAS_EC > 0
      format atmp as @RVC{09},@CKNUM{04},@CHK_OPEN_TIME
      call update_check_flags (atmp) 
   endif
		 
   call close_odbc
   G_HAS_EC = 0


endsub

event srvc_total : *
   var atmp : A256 = ""
   var mylname : A80 = ""
   var myfname : A80 = ""
   var mychkname : A80 = ""
   var myrvcname : A80 = ""
   var myrvcseq : A80 = ""
   var mytable : A80 = ""
   var sti : N9 = 0
   var iv_msg[20] : A128
   var iv_stat : A1024 = ""
   var iv_results : A1024 = ""

   call check_server_mode
   call check_uws 
   call clear_current_round
   call read_ename_obj (@TREMP, iv_stat, mylname, myfname, mychkname)
   call read_rvcname (iv_stat, myrvcname, myrvcseq)
   call read_table (myrvcseq, iv_stat, mytable)

   call init_odbc (iv_stat)
   if iv_stat <= 0
      errormessage "ODBC Init Error: ", iv_stat
      return
   endif

   sti = 1
   format iv_msg[sti] as "Service Total: "{<20}, TXT_CHECK, " ", @CKNUM, " ", @CKID
   call send_msg (0, 1, iv_msg[], sti, iv_stat, iv_results)

   if G_HAS_EC > 0
      format atmp as @RVC{09},@CKNUM{04},@CHK_OPEN_TIME
      call update_check_flags (atmp) 
   endif
		 
   call close_odbc
   
   call do_split_xfer
   
   G_HAS_EC = 0
endevent

event dsc
   call check_server_mode
   call check_uws 
   call do_dsc
endevent
event dsc_void
   call check_server_mode
   call check_uws 
   G_VTYPE = VOID_TEXT
   call check_current_round
endevent
event dsc_Error_Correct_Items
   call check_server_mode
   call check_uws 
   G_VTYPE = EC_TEXT
   call check_current_round
   G_HAS_EC = 1
endevent

event mi
   call check_server_mode
   call check_uws 
   call do_mi
endevent
event mi_void_items
   call check_server_mode
   call check_uws 
   G_VTYPE = VOID_TEXT
   call check_current_round 
endevent
event Mi_Error_Correct_Items
   call check_server_mode
   call check_uws 
   G_VTYPE =EC_TEXT
   G_HAS_EC = 1
   call check_current_round
endevent

event svc
   call check_server_mode
   call check_uws 
   call do_svc
endevent
event svc_void
   call check_server_mode
   call check_uws 
   G_VTYPE = VOID_TEXT
   call check_current_round
endevent
event svc_Error_Correct_Items
   call check_server_mode
   call check_uws 
   G_VTYPE = EC_TEXT
   G_HAS_EC = 1
   call check_current_round
endevent

event inq : SIM_NO_SALE_INQ
   // This loads No Sale and then send the message
   var mk : Key
   var data : A100 = ""
   var im_tbl : A20 

   if @TREMP <= 0
      errormessage "Sign In First"
      exitcancel
   endif
   if @CKNUM > 0
      errormessage "Open Check Not Allowed"
      exitcancel
   endif


   if @instandalonemode <= 0 AND @InBackupMode <= 0
      call do_sim_no_sale
   endif

   loadkybdmacro key (1, NO_SALE_KEY), @KEY_ENTER
   call check_uws 
   
   G_HAS_EC = 0
   G_SPLIT_TYPE = 0
   G_SPLIT_EMP = 0
   G_sx_date_time = ""

endevent


//---------------------------------------------------------------------------------------------
// UWS Startup
//---------------------------------------------------------------------------------------------
sub do_wsup
   var iv_msg[20] : A128
   var wui : N9 = 0
   var iv_stat : A1024 = ""
   var iv_results : A1024 = ""
   
   // <wsid>Startup

   call init_odbc (iv_stat)
   if iv_stat <= 0
      errormessage "ODBC Init Error: ", iv_stat
      return
   endif

   wui=1
   format iv_msg[wui] as  "Startup"
   call send_msg (2, 2, iv_msg[],wui, iv_stat, iv_results)
		 
   call close_odbc
   G_HAS_EC = 0


endsub

//---------------------------------------------------------------------------------------------
// Clock In Messages
//---------------------------------------------------------------------------------------------

sub do_clock_in
   var iv_msg[20] : A128 
   var iv_stat : A1024 = ""
   var iv_results : A1024 = ""
   var mylname : A80 = ""
   var myfname : A80 = ""
   var mychkname : A80 = ""
   var ci : N9 = 0

   // <wsid>Clock In: 1234345 Jones, Paul
   if trim(G_CurrentEID) = ""
      return
   endif

   call read_ename_id (trim(G_CurrentEID), iv_stat, mylname, myfname, G_CurrentEmp, mychkname)

   call init_odbc (iv_stat)
   if iv_stat <= 0
      errormessage "ODBC Init Error: ", iv_stat
      return
   endif

   ci = 1
   format iv_msg[ci] as "Clock In: ", G_CurrentEmp, " ", mylname, ", ", myfname
   call send_msg (2, 2, iv_msg[], ci, iv_stat, iv_results)
		 
   G_CurrentEmp = 0
   G_CurrentELName = ""
   G_CurrentEFName = ""
   G_CurrentEID = ""
   call close_odbc
endsub

sub do_clock_out
   var iv_msg[20] : A128 
   var coi : N9 = 0
   var iv_stat : A1024 = ""
   var iv_results : A1024 = ""
   var mylname : A80 = ""
   var myfname : A80 = ""
   var mychkname : A80 = ""
   
   // <wsid>Clock Out: 1234345 Jones, Paul
   if trim(G_CurrentEID) = ""
      return
   endif

   call read_ename_id (trim(G_CurrentEID), iv_stat, mylname, myfname, G_CurrentEmp, mychkname)

   call init_odbc (iv_stat)
   if iv_stat <= 0
      errormessage "ODBC Init Error: ", iv_stat
      return
   endif

   coi = 1
   format iv_msg[coi] as "Clock Out: ", G_CurrentEmp, " ", mylname, ", ", myfname
   call send_msg (2, 2, iv_msg[], coi, iv_stat, iv_results)
		 
   // call close_odbc
   G_CurrentEmp = 0
   G_CurrentELName = ""
   G_CurrentEFName = ""
   G_CurrentEID = ""
   call close_odbc

endsub
//---------------------------------------------------------------------------------------------
//Sign In Messages
//---------------------------------------------------------------------------------------------
sub do_signin
   var mylname : A80 = ""
   var mychkname : A80 = ""
   var myfname : A80 = ""
   var myrvcname : A80 = ""
   var myrvcseq : A80 = ""
   var iv_msg[20] : A128
   var iv_stat : A1024 = ""
   var iv_results : A1024 = ""
   var sii : N9 = 0
   
   if @TREMP <= 0
      errormessage "Invalid Employee"
      return
   endif

   call read_ename_obj (@TREMP, iv_stat, mylname, myfname, mychkname)
   call read_rvcname (iv_stat, myrvcname, myrvcseq)

   // <wsid>Sign In      123456789 Smith, John
   // <wsid>Restaurant
   // <wsid>Emp 123456789 Smith, John	

   call init_odbc (iv_stat)
   if iv_stat <= 0
      errormessage "ODBC Init Error: ", iv_stat
      return
   endif

   sii = 1
   cleararray iv_msg
   format iv_msg[sii] as "Sign In         ", @TREMP, " ", mylname, ", ", myfname
   sii = sii+1
   // call send_msg (1, 1, iv_msg, iv_stat, iv_results)
   format iv_msg[sii] as  @RVC, " ", myrvcname
   sii = sii+1
   // call send_msg (0, 1, iv_msg, iv_stat, iv_results)
   format iv_msg[sii] as  "Emp ", @TREMP, " ", mylname, ", ", myfname
   call send_msg (0, 1, iv_msg[], sii, iv_stat, iv_results)
		 
   // call close_odbc
   call close_odbc


endsub
sub do_signout
   var mylname : A80 = ""
   var myfname : A80 = ""
   var myrvcname : A80 = ""
   var iv_msg[20] : A128 
   var soi : N9 = 0
   var iv_stat : A1024 = ""
   var iv_results : A1024 = ""
   
   // No TREMP set here, because its after the sign out...
   // If G_CurrentEmp <> 0, assume they are the signed in employee,
   // and send them.
   // Otherwise, just forget it.

   if G_CurrentEmp <= 0
      //errormessage "Invalid Employee: ", @TREMP
      return
   endif

   // <wsid>Sign In      123456789 Smith, John
   // <wsid>Restaurant
   // <wsid>Emp 123456789 Smith, John	

   call init_odbc (iv_stat)
   if iv_stat <= 0
      errormessage "ODBC Init Error: ", iv_stat
      return
   endif

   soi = 1
   format iv_msg[soi] as "Sign Out         ", G_CurrentEmp,\
        " ", G_CurrentELname, ", ", G_CurrentEFname
   call send_msg (2, 1, iv_msg[],soi, iv_stat, iv_results)
   // call send_msg (GMsgSeparator, iv_stat, iv_results)
		 
   // call close_odbc
   call close_odbc

endsub

//---------------------------------------------------------------------------------------------
//  Tender messages
//---------------------------------------------------------------------------------------------
sub do_tender 
   var atmp : A1024 = ""
   var mylname : A80 = ""
   var myfname : A80 = ""
   var mychkname : A80 = ""
   var myrvcname : A80 = ""
   var mytmedname : A80 = ""
   var mytable : A80 = ""
   var iv_msg[20] : A128
   var iv_stat : A1024 = ""
   var iv_results : A1024 = ""
   var chgdue : $12 = 0
   var chgdue_obj : N9 = 0
   var chgdue_name : A80 = ""
   var myrvcseq : A20 = ""
   var myi : N9 = 0
   var dtti : N9 = 0
   var tender_sign : N9 = 0
   var detail_sign : N9 = 0
   var chgtip_ttl : $12 = 0
   var chgtip_name :A80 = ""

   // ---------------------------------------------------------------------------------------
   // Figure out if thre is change due.  
   // ---------------------------------------------------------------------------------------
   var  has_tmp : N1 = 1
   if HAS_INEDIT > 0 and HAS_INREOPEN > 0
      if @InReopenClosedCheck <= 0 or @InEditClosedCheck <= 0
         has_tmp = 0
      endif
   endif
   if @TTLDUE = 0 or has_tmp = 1

      if @TNDTTL > 0
         tender_sign = 1
      endif
      if @TNDTTL < 0
         tender_sign = -1
      endif

      var xtcount : N9 = 0
      var endpos : N9 = @NUMDTLT - @NUMDTLR + 1
      for myi = @NUMDTLT to endpos step -1
         xtcount = xtcount + 1
	 if xtcount > 1 AND chgdue <> 0
	    break
	 endif
	 if xtcount > 2
	    break
	 endif
	 detail_sign = 0
         if @DTL_TYPE[myi] <> "T" and @DTL_TYPE[myi] <> "R"
	    break
	 endif
         if @DTL_TYPE[myi] = "T" 
	    // Sign of this tender...
	    if @DTL_TTL[myi] > 0
	          detail_sign = 1
	    endif
	    if @DTL_TTL[myi] < 0
	          detail_sign = -1
	    endif
         endif  

         // if its change due, then the last tender sign will be different than the
         // actual tender sign.
	 // errormessage "CD Check: ", @DTL_NAME[myi], ":", @DTL_TTL[myi],":",detail_sign,":", tender_sign
         if (detail_sign = -1 * tender_sign) and detail_sign <> 0
            chgdue = @DTL_TTL[myi] 
            chgdue_obj =  @DTL_OBJECT[myi] 
            chgdue_name =  @DTL_NAME[myi] 
	    break
         endif 
      endfor
    endif 
   endif

   chgtip_ttl = 0
   chgtip_name = 0
   // errormessage HAS_CHGTIP
   mytmedname = "Unknown"
      for myi=@NUMDTLT to 1 step -1
        if @DTL_TYPE[myi] = "T" 
           if @TNDTTL = @DTL_TTL[myi]
	      // THis is our tender...
	      mytmedname = @DTL_NAME[myi]
	      if HAS_CHGTIP > 0
                 // errormessage @DTL_TTL[myi], ":", @Dtl_Charge_Tip_Amount[myi]
                 chgtip_ttl = @Dtl_Charge_Tip_Amount[myi]
                 chgtip_name = @Dtl_Charge_Tip_Name[myi]
	      endif
	      break
	   endif
	endif
      endfor
   
   // <wsid>Tender Check 1234	
   // <wsid>Restaurant 	Table 123  
   // <wsid>Emp 123456789 Smith, John   
   // <wsid>04/22/2007 12:22:42	
   // <wsid>1    Tax	      	2.50
   // <wsid>1    Cash	      	25.00
   // <wsid>1    Change Due      	1.32
   // <wsid>Close Check 1234	

   var mytax :$12 = 0
   for myi=1 to 8
      mytax = mytax + @TAX[myi]
   endfor

   call read_ename_obj (@TREMP, iv_stat, mylname, myfname, mychkname)
   call read_rvcname (iv_stat, myrvcname, myrvcseq)
   call read_table (myrvcseq, iv_stat, mytable)

   chgdue_name = "Change Due"
   chgtip_name = "Charge Tip"


   call init_odbc (iv_stat)
   if iv_stat <= 0
      errormessage "ODBC Init Error: ", iv_stat
      return
   endif

   dtti = 1
   format iv_msg[dtti] as "Tender"{<20}, TXT_CHECK, " ", @CKNUM, " ", @CKID
   	//call send_msg (2, 1, iv_msg, iv_stat, iv_results)
   dtti = dtti + 1
   format iv_msg[dtti] as myrvcname,"   ", TXT_TABLE, " ", mytable, "/", @GRPNUM
   	//call send_msg (0, 1, iv_msg, iv_stat, iv_results)
   dtti = dtti + 1
   format iv_msg[dtti] as "Emp: ", @TREMP, " ", mylname, ", ", myfname
   	//call send_msg (0, 1, iv_msg, iv_stat, iv_results)

   format atmp as  @MONTH{02}, "/", @DAY{02}, "/", @YEAR{02}, \
                   @HOUR{02}, ":", @MINUTE{02}, ":", @SECOND{02}
   dtti = dtti + 1
   format iv_msg[dtti] as atmp
   	//call send_msg (0, 1, iv_msg, iv_stat, iv_results)

   dtti = dtti + 1
   format iv_msg[dtti] as TXT_TAXTTL{<20}, mytax{>12}
   	//call send_msg (0, 1, iv_msg, iv_stat, iv_results)
   if chgtip_ttl <> 0
      dtti = dtti + 1
      format iv_msg[dtti] as TXT_CHGTIP{<20}, chgtip_ttl{>12}
      	//call send_msg (0, 1, iv_msg, iv_stat, iv_results)
   endif
   dtti = dtti + 1
   format iv_msg[dtti] as mytmedname{<20}, @TNDTTL{>12}
   	//call send_msg (0, 1, iv_msg, iv_stat, iv_results)
   if chgdue <> 0
      dtti = dtti + 1
      format iv_msg[dtti] as TXT_CHANGEDUE{<20}, chgdue{>12}
      	//call send_msg (0, 1, iv_msg, iv_stat, iv_results)
   endif
   dtti = dtti + 1

   call send_msg (0, 1, iv_msg[], dtti, iv_stat, iv_results)

   // Mark our EC, in case we are not service totalling.  THis happens
   // before final tender...
   if G_HAS_EC > 0
      format atmp as @RVC{09},@CKNUM{04},@CHK_OPEN_TIME
      call update_check_flags (atmp) 
   endif
		 
   call close_odbc
   // call close_odbc

   // Store the current round detail in the list
   call save_current_round 
   
   // errormessage "TNDR"
endsub


//---------------------------------------------------------------------------------------------
//  Menu Item messages
//---------------------------------------------------------------------------------------------
sub clear_current_round
      G_VTYPE = ""
      NG_DTL = 0
      cleararray G_DTL_DTL
      cleararray G_DTL_TYPE
      cleararray G_DTL_OBJ
      cleararray G_DTL_NAME
      cleararray G_DTL_TTL
      cleararray G_DTL_QTY
      cleararray G_DTL_CT_TTL

endsub

sub save_current_round 

   var myi : N9 = 0
   var x : N9
   var y : N9
   var startpos : N9

   // Add all the current round items to our list.
   startpos = @NUMDTLT - @NUMDTLR
   if startpos+1 <= 0 or startpos+1 > @NUMDTLT
     return
   endif

   call clear_current_round

   var cri : N9 = 0
   NG_DTL = 0
   for myi = startpos+1 to @NUMDTLT  
	if @dtl_type[myi] = "M" or \ 
	   @dtl_type[myi] = "S" or \ 
	   @dtl_type[myi] = "T" or \ 
	   @dtl_type[myi] = "D"

              cri = cri + 1
	      NG_DTL = NG_DTL + 1
              G_DTL_DTL[cri] = myi
	      G_DTL_TYPE[cri] = @DTL_TYPE[myi]
              G_DTL_OBJ[cri]  = @DTL_OBJECT[myi]
              G_DTL_NAME[cri] = @DTL_NAME[myi]
              G_DTL_TTL[cri] = @DTL_Ttl[myi]
              G_DTL_QTY[cri] = @DTL_Qty[myi]
              G_DTL_MLVL[cri] = @DTL_MLVL[myi]
	      if HAS_CHGTIP > 0
                 G_DTL_CT_TTL[cri] = @DTL_Charge_Tip_Amount[myi]
	      endif
              // errormessage "Adding : ",cri,":", G_DTL_NAME[cri],":", G_DTL_TTL[cri] 
	endif
   endfor
   GLastExtraDtl = @NUMDTLT

endsub

sub check_current_round 

   var myi : N9 = 0
   var x : N9
   var y : N9
   var startpos : N9
   var dtl : N9 = 0
   var ishere : N1 = 0
   var chgtip_ttl : $12 = 0
   var myminame : A128 = ""
   
   // Void-Void causes the last item to disappear.  That means that we can scan thru this
   // list and see waht has changed.  Then, missing items will be sent.
   // Items that appear in detail but are not in this list will
   // not be sent, as they should be caught in the event
   // that added them to the check.
   // errormessage "Checking Removed: ", NG_DTL, ":", @NUMDTLT, ":", @NUMDTLR
   if NG_DTL > 0
      startpos = @NUMDTLT - @NUMDTLR +1
      if startpos <= 0 or startpos > @NUMDTLT
        return
      endif
   
      // Find items that are missing now, or that are still there but have changed.
      // 
      var skip_me[MAX_DTL] : N1
      cleararray skip_me
      for myi = NG_DTL to 1 step -1 
            ishere = 0
            for dtl = @NUMDTLT to startpos step -1 
	      if @dtl_type[dtl] = "M" or \ 
	         @dtl_type[dtl] = "S" or \ 
	         @dtl_type[dtl] = "T" or \ 
	         @dtl_type[dtl] = "D"
	          if skip_me[dtl] <> 1
	             if G_DTL_TYPE[myi] = @DTL_TYPE[dtl] and \
	                G_DTL_OBJ[myi] = @DTL_OBJECT[dtl] and \
	                G_DTL_NAME[myi] = @DTL_NAME[dtl] and \
	                G_DTL_TTL[myi] = @DTL_TTL[dtl] and \
	                G_DTL_QTY[myi] = @DTL_QTY[dtl] 
 	                if HAS_CHGTIP > 0
                            G_DTL_CT_TTL[myi] = @DTL_Charge_Tip_Amount[dtl]
	                endif
                    
	                ishere = 1
		        skip_me[dtl] = 1
		        break
	             endif
	          endif
	          //errormessage "checking: ",myi, ":",  G_DTL_TTL[myi],  ":",dtl, ":", @DTL_TTL[dtl]  
	       endif
	    endfor
            // This previosly present detail line is now gone.
	    //errormessage "Here: ",myi, ":", ishere
	    if ishere = 0
                 // errormessage "Would Send: ",G_DTL_DTL[myi], ":", G_DTL_NAME[myi],  ":", G_DTL_TTL[myi] 
	          G_DTL_TTL[myi] = -1*G_DTL_TTL[myi]
	          if G_DTL_TYPE[myi] = "T"
                     call send_tender_void ("EC", G_DTL_NAME[myi], G_DTL_TTL[myi], 0, G_DTL_CT_TTL[myi] ) 
	          elseif  G_DTL_TYPE[myi] = "D"
                     call send_dms_void ( G_DTL_NAME[myi], G_DTL_TTL[myi], G_DTL_QTY[myi]) 
	          elseif  G_DTL_TYPE[myi] = "S"
                     call send_dms_void ( G_DTL_NAME[myi], G_DTL_TTL[myi], G_DTL_QTY[myi]) 
	          elseif  G_DTL_TYPE[myi] = "M"
                     call set_dtl_name (G_DTL_OBJ[myi], G_DTL_MLVL[myi], @RVC, myminame)
                     call send_dms_void ( myminame, G_DTL_TTL[myi], G_DTL_QTY[myi]) 
                     // call send_dms_void ( G_DTL_NAME[myi], G_DTL_TTL[myi], G_DTL_QTY[myi]) 
	          endif
	    endif
      endfor
   endif // if no current round detail has been saved yet


   // Now, lets check for stuff that has shown up beyond our list.  These would be
   // mostly voided items that were added and the void event never fired or fired incorreclt.
   var last_sign : N9 = 0
   var this_sign : N9 = 0
   // errormessage "Checking New Detail: ", GLastExtraDtl, ":", @NUMDTLT
   if GLastExtraDtl > 0
      startpos = GLastExtraDtl + 1
   else
      startpos = @NUMDTLT - @NUMDTLR +1
   endif
   if startpos > 0 and startpos <= @NUMDTLT

      for myi = startpos to @NUMDTLT  
         if @dtl_type[myi] = "M" or \ 
	   @dtl_type[myi] = "S" or \ 
	   @dtl_type[myi] = "T" or \ 
	   @dtl_type[myi] = "D"

            // Missing this one...
	    // Send the detail...

	       if @dtl_type[myi] = "T"
	          if last_sign <> 0 
		     if @DTL_TTL[myi] > 0
		        this_sign = 1
		     else
		        this_sign = -1
		     endif
		  endif

                  chgtip_ttl = 0
 	          if HAS_CHGTIP > 0
                     chgtip_ttl = @DTL_Charge_Tip_Amount[myi]
	          endif
		  
             //errormessage "Would Send New: ",G_DTL_DTL[myi], ":", @DTL_NAME[myi],  ":", @DTL_TTL[myi], \
	     //   ":",  last_sign, ":", this_sign
		
		  if (this_sign = -1 * last_sign) AND (this_sign <> 0 AND last_sign <> 0)
		     //errormessage "CD: ", this_sign, ":", last_sign
		     if (this_sign < 0) 
		        chgtip_ttl = this_sign * chgtip_ttl
		     endif
                     call send_tender_void ( VOID_TEXT, "Change Due", @DTL_TTL[myi], 0, chgtip_ttl) 
		     this_sign = 0
		     last_sign = 0
		  else
                     call send_tender_void ( VOID_TEXT, @DTL_NAME[myi], @DTL_TTL[myi], 0, chgtip_ttl) 
		  endif

		  if @DTL_TTL[myi] > 0
		        last_sign = 1
		  else
		        last_sign = -1
		  endif
	       elseif  @dtl_type[myi] = "D"
                  call send_dms_void ( @DTL_NAME[myi], @DTL_TTL[myi], @DTL_QTY[myi]) 
	       elseif  @dtl_type[myi] = "S"
                  call send_dms_void ( @DTL_NAME[myi], @DTL_TTL[myi], @DTL_QTY[myi]) 
	       elseif  @dtl_type[myi] = "M"
                  call set_dtl_name (@DTL_OBJECT[myi], @DTL_MLVL[myi], @RVC, myminame)
                  call send_dms_void ( myminame, @DTL_TTL[myi], @DTL_QTY[myi]) 
                  // call send_dms_void ( @DTL_NAME[myi], @DTL_TTL[myi], @DTL_QTY[myi]) 
	       endif

         endif
      endfor
   endif

   call save_current_round 
endsub

sub send_tender_void (var mytype : A10, var mytmedname : A40, var mytmedttl : $12, var changedue : $12, var ct_ttl : $12) 
   var mylname : A80 = ""
   var myfname : A80 = ""
   var mychkname : A80 = ""
   var myrvcname : A80 = ""
   var myrvcseq : A80 = ""
   var atmp : A256 = ""
   var mytable : A80 = ""
   var iv_msg[20] : A128 
   var iv_stat : A1024 = ""
   var iv_results : A1024 = ""
   var chgdue_name : A40 = "Change Due"
   var chgdue : $12 = 0
   var ct_name : A40 = "Charge Tip"
   var stvi : N9 = 0

   call read_ename_obj (@TREMP, iv_stat, mylname, myfname, mychkname)
   call read_rvcname (iv_stat, myrvcname, myrvcseq)
   call read_table (myrvcseq, iv_stat, mytable)

//errormessage "TV: ",mytmedname, " ", mytmedttl, ":", chgdue, ":",ct_ttl

   call init_odbc (iv_stat)
   if iv_stat <= 0
      errormessage "ODBC Init Error: ", iv_stat
      return
   endif

   stvi = 1
   format iv_msg[stvi] as mytype, " Tender"{<20}, TXT_CHECK, " ", @CKNUM, " ", @CKID
   	//call send_msg (2, 1, iv_msg, iv_stat, iv_results)
   stvi = stvi + 1
   format iv_msg[stvi] as myrvcname,"   ", TXT_TABLE, " ", mytable, "/", @GRPNUM
   	//call send_msg (0, 1, iv_msg, iv_stat, iv_results)
   stvi = stvi + 1
   format iv_msg[stvi] as "Emp: ", @TREMP, " ", mylname, ", ", myfname
   	//call send_msg (0, 1, iv_msg, iv_stat, iv_results)

   format atmp as  @MONTH{02}, "/", @DAY{02}, "/", @YEAR{02}, \
                   @HOUR{02}, ":", @MINUTE{02}, ":", @SECOND{02}
   stvi = stvi + 1
   format iv_msg[stvi] as atmp
   	//call send_msg (0, 1, iv_msg, iv_stat, iv_results)

   if ct_ttl <> 0
       stvi = stvi + 1
       format iv_msg[stvi] as TXT_CHGTIP{<20}, ct_ttl{>12}
       	//call send_msg (0, 1, iv_msg, iv_stat, iv_results)
   endif
   stvi = stvi + 1
   format iv_msg[stvi] as mytmedname{<20}, mytmedttl{>12}
   	//call send_msg (0, 1, iv_msg, iv_stat, iv_results)
   if chgdue <> 0
       stvi = stvi + 1
       format iv_msg[stvi] as TXT_CHANGEDUE{<20}, changedue{>12}
       	//call send_msg (0, 1, iv_msg, iv_stat, iv_results)
   endif
   // stvi = stvi + 1
   // format iv_msg[stvi] as GMsgSeparator
   call send_msg (0, 1, iv_msg[], stvi, iv_stat, iv_results)
		 
   call close_odbc


endsub

sub send_dms_void ( var myname : A40, var myttl : $12, var myqty : A40) 
   var mylname : A80 = ""
   var myfname : A80 = ""
   var myrvcname : A80 = ""
   var mytable : A80 = ""
   var iv_msg[20] : A128
   var iv_stat : A1024 = ""
   var iv_results : A1024 = ""
   var dmvi : N9 = 1

   call init_odbc (iv_stat)
   if iv_stat <= 0
      errormessage "ODBC Init Error: ", iv_stat
      return
   endif

   dmvi = 1
   format iv_msg[dmvi] as G_VTYPE, "  ",myqty{<4}, myname{<30}, myttl{>12}
   call send_msg (0, 1, iv_msg[], dmvi, iv_stat, iv_results)
		 
   // call close_odbc
   call close_odbc


endsub

sub do_mi
   var atmp : A1024 = ""
   var myttl : $12 = 0
   var myqty : A40 = ""
   var myminame : A80 = ""
   var iv_msg[20] : A128
   var iv_stat : A1024 = ""
   var iv_results : A1024 = ""
   var myi : N9 = 0
   var mii : N9 = 0

   
   myminame = "Unknown"
      for myi=@NUMDTLT to 1 step -1
        if @DTL_TYPE[myi] = "M" 
	      // THis is our MI
	      //myminame = @DTL_NAME[myi]
	      myttl = @DTL_TTL[myi]
	      myqty = @DTL_QTY[myi]
              call set_dtl_name (@DTL_OBJECT[myi], @DTL_MLVL[myi], @RVC, myminame)
	      break
	   endif
	endif
      endfor
   
   call init_odbc (iv_stat)
   if iv_stat <= 0
      errormessage "ODBC Init Error: ", iv_stat
      return
   endif

   mii = 1
   format iv_msg[mii] as myqty{<4}, myminame{<30}, myttl{>12}

   call send_msg (0, 1, iv_msg[], mii, iv_stat, iv_results)

   call close_odbc
   // call close_odbc
   // Store the current round detail in the list
   call save_current_round 

endsub

//---------------------------------------------------------------------------------------------
//  Discount messages
//---------------------------------------------------------------------------------------------
sub do_dsc
   var atmp : A1024 = ""
   var myqty : A80 = ""
   var myttl : $12 = 0
   var mytmedname : A80 = ""
   var iv_msg[20] : A128
   var iv_stat : A1024 = ""
   var iv_results : A1024 = ""
   var myi : N9 = 0
   var dsci : N9 = 0

   mytmedname = "Unknown"
      for myi=@NUMDTLT to 1 step -1
        if @DTL_TYPE[myi] = "D" 
	      // THis is our discount
	      mytmedname = @DTL_NAME[myi]
	      myttl = @DTL_TTL[myi]
	      myqty = @DTL_QTY[myi]
	      break
	   endif
	endif
      endfor
   
   call init_odbc (iv_stat)
   if iv_stat <= 0
      errormessage "ODBC Init Error: ", iv_stat
      return
   endif

   dsci = 1
   format iv_msg[dsci] as myqty{<4}, mytmedname{<20}, myttl{>12}
   call send_msg (0, 1, iv_msg[], dsci, iv_stat, iv_results)

   // call close_odbc
   call close_odbc

   // Store the current round detail in the list
   call save_current_round 
   
endsub


//---------------------------------------------------------------------------------------------
//  Service Charge messages
//---------------------------------------------------------------------------------------------
sub do_svc
   var atmp : A1024 = ""
   var myttl : $12 = 0
   var myqty : A80 = ""
   var myminame : A80 = ""
   var iv_msg[20] : A128
   var iv_stat : A1024 = ""
   var iv_results : A1024 = ""
   var myi : N9 = 0
   var dsvci : N9 = 0

   myminame = "Unknown"
      for myi=@NUMDTLT to 1 step -1
        if @DTL_TYPE[myi] = "S" 
	      // THis is our SVC
	      myminame = @DTL_NAME[myi]
	      myttl = @DTL_TTL[myi]
	      myqty = @DTL_QTY[myi]
	      break
	   endif
	endif
      endfor
   
   call init_odbc (iv_stat)
   if iv_stat <= 0
      errormessage "ODBC Init Error: ", iv_stat
      return
   endif

   dsvci = 1
   format iv_msg[dsvci] as myqty{<4}, myminame{<30}, myttl{>12}
   call send_msg (0, 1, iv_msg[], dsvci, iv_stat, iv_results)

   // call close_odbc
   call close_odbc
   // Store the current round detail in the list
   call save_current_round 
   


endsub

sub get_pickup_status
   var set_i : N9 = 0

   im_reopen = 0
   im_edit = 0
   if HAS_INREOPEN = 1
      if @InReopenClosedCheck 
         im_reopen = 1
      endif
   endif
   if HAS_INEDIT = 1
      if @InEditClosedCheck 
         im_edit = 1
      endif
   endif

endsub

//---------------------------------------------------------------------------------------------
// WS Exit Messages
//---------------------------------------------------------------------------------------------
sub do_wsdown
   var iv_msg[20] : A128
   var iv_stat : A1024 = ""
   var iv_results : A1024 = ""
   var wsdi : N9 = 1
   
   // <wsid>Shutdown

   call init_odbc (iv_stat)
   if iv_stat <= 0
      errormessage "ODBC Init Error: ", iv_stat
      return
   endif

   wsdi = 1
   format iv_msg[wsdi] as "Shutdown"
   call send_msg (2, 2, iv_msg[], wsdi, iv_stat, iv_results)
		 
   call close_odbc
   // call close_odbc

endsub
//---------------------------------------------------------------------------------------------
// Trans Cancel Messages
//---------------------------------------------------------------------------------------------
sub do_trans_cncl
   var mylname : A80 = ""
   var myfname : A80 = ""
   var myrvcname : A80 = ""
   var iv_msg[20] : A128
   var iv_stat : A1024 = ""
   var iv_results : A1024 = ""
   var tci : N9 = 0
   var tck : N9 = 0
   var tcs : N9 = 0
   var tctmp : $12 = 0
   var tcstmp : A1024 = ""

   // errormessage "Trans Cancel: ", @CKNUM
   
   call init_odbc (iv_stat)
   if iv_stat <= 0
      errormessage "ODBC Init Error: ", iv_stat
      return
   endif

   if G_HAS_EC > 0
      format tcstmp as @RVC{09},@CKNUM{04},@CHK_OPEN_TIME
      call update_check_flags (tcstmp) 
   endif
   tcstmp = ""

   tci = 1
   if @CKNUM > 0
      format iv_msg[tci] as "<", @WSID, ">", "Transaction Cancel ", @CKNUM
   else
      format iv_msg[tci] as "<", @WSID, ">", "Transaction Cancel "
   endif

   // Summary Message
   // Lets add up the current round amounts and put that on the end.  Thats what is being
   // cancelled...
   tctmp = 0

   if @NUMDTLR > 0
      tcs =  @NUMDTLT - @NUMDTLR + 1
      //errormessage tcs, ":", @NUMDTLT
      for tck= tcs to @NUMDTLT
         if @DTL_TTL[tck] <> "0.00" and @DTL_TTL[tck] <> "-0.00"
            tctmp = tctmp + @DTL_TTL[tck]
	    //errormessage tck, ":", @DTL_TTL[tck], ":", tctmp
	 endif
      endfor
   endif

   if len(trim(STXT_EMP_PRE)) > 0
      tci = tci + 1
      call get_sum_tags (tcstmp, tcs) 
      format iv_msg[tci] as STXT_EMP_PRE, @TREMP_CHKNAME, "  ", STXT_CANCEL, "  ", tcstmp, "  ",tctmp 
      if len(iv_msg[tci]) > MAX_MSG_LEN
         // errormessage "Trunc: ", iv_msg[tci]
         // errormessage mid(iv_msg[tci], 40, 50)
         tcstmp = mid(iv_msg[tci], 1, MAX_MSG_LEN)
         iv_msg[tci] = tcstmp
      endif
   endif

   call send_msg (1, 1, iv_msg[], tci, iv_stat, iv_results)
		 
   call close_odbc
   // call close_odbc


endsub


//---------------------------------------------------------------------------------------------
// No Sale Messages
//---------------------------------------------------------------------------------------------
sub do_sim_no_sale 
   var iv_msg[20] : A128
   var iv_stat : A1024 = ""
   var iv_results : A1024 = ""
   var snsi : N9 = 0
   var snatmp : A128 = ""
   var mylname : A80 = ""
   var myfname : A80 = ""
   var mychkname : A80 = ""
   var myrvcname : A80 = ""
   
   // <wsid>No Sale

   call check_server_mode
   call init_odbc (iv_stat)
   if iv_stat <= 0
      errormessage "ODBC Init Error: ", iv_stat
      return
   endif
   call read_ename_obj (@TREMP, iv_stat, mylname, myfname, mychkname)

   snsi = 1
   format iv_msg[snsi] as  "No Sale"

   // Summary Message
  
   if len(trim(STXT_EMP_PRE)) > 0
      snsi = snsi + 1
      format iv_msg[snsi] as STXT_EMP_PRE, mychkname, " ", STXT_NOSALE
      if len(iv_msg[snsi]) > MAX_MSG_LEN
         errormessage "Trunc: ", iv_msg[snsi]
         snatmp = mid(iv_msg[snsi], 1, MAX_MSG_LEN)
         iv_msg[snsi] = snatmp
      endif
   endif
   call send_msg (1, 1, iv_msg[], snsi, iv_stat, iv_results)

   call close_odbc

endsub

sub assume_decimal (ref string, ref decimal)
  var dtmp : $12 = 0
  var dtmp2 : $12 = 0
  var pos : N9 = 0
  var ntmp : N9 = 0
  var atmp : A40 = ""
  var atmp2 : A40 = ""

         pos = instr(1,string,".")
         if pos <> 0 
            dtmp = string
         else
            dtmp2 = string
            dtmp = dtmp2 / 100
         endif
         decimal = dtmp
endsub
sub get_amount(ref myamt)
   var mydata : A40 = @USERENTRY

   call assume_decimal (mydata, myamt)
   if myamt <= 0 
      input mydata, "Enter Amount"
   endif
   if @INPUTSTATUS <= 0
      exitcancel
   endif
   call assume_decimal (mydata, myamt)
   if myamt <= 0 
      exitcancel
   endif
endsub

// ---------------------------------------------------------
// Read IV Parameters from text file
// ---------------------------------------------------------
sub get_sum_tags (ref gst_sum_line, var mydtlstart : N9) 
   var gsti : N9 = 0
   var gstk : N9 = 0
   var gstpos : N9 = 0
   var gsttaglen : N9 = 0
   var gstspos : N9 = 0
   var keepon : N1 = 0
   var reps : N9 = 0
   var gsttmp : A256 = ""
   var gsttmp2 : A256 = ""

   var STX_USED[999] : N1

   if len(trim(STXT_EMP_PRE)) <= 0
      return
   endif   

   if mydtlstart > 0
   
      for gsti=mydtlstart to @NUMDTLT
         if @DTL_TYPE[gsti] = "M" OR \
	    @DTL_TYPE[gsti] = "S" OR \
	    @DTL_TYPE[gsti] = "D" OR \
	    @DTL_TYPE[gsti] = "T"

	    gsttmp = trim(@DTL_NAME[gsti])

	    // for each text item, scan this dtl name
	    for gstk = 1 to N_STXT_DTLS
	       
	       keepon = 1
	       gstspos = 1
	       reps = 0
	       gsttaglen = len(STXT_DTL_NAMES[gstk])
	       reps = 0
	       while keepon > 0
		  reps = reps + 1
		  if reps > 99
		     break
		  endif
                  keepon = 0
                  gstpos = instr (gstspos, gsttmp, mid(STXT_DTL_NAMES[gstk],1,1) )
                  gstspos = gstpos + 1
		  //errormessage gsttmp,":", STXT_DTL_NAMES[gstk] , ":", gstpos
	          if gstpos > 0
                     if mid(gsttmp, gstpos, gsttaglen) = STXT_DTL_NAMES[gstk]
                        STX_USED[gstk] = 1
			keepon = 0
		     else
		        keepon = 1
		     endif
	          endif
               endwhile
	    endfor
	 endif
      endfor
   endif

   // Now, build the summary string
   gsttmp = ""

   // Chekc for evoids...
   format gsttmp2 as @RVC{09}, @CKNUM{04}, @CHK_OPEN_TIME
   var gshasec : N9 = 0
   call check_if_ec (gsttmp2, gshasec)
   // errormessage gshasec, ":", STXT_EVOID
   if gshasec > 0
      format gsttmp as gsttmp, STXT_EVOID, "  "
   endif

   // Now the voids.
   for gstk = 1 to @NUMDTLT
      if @DTL_IS_VOID[gstk] > 0
	 //errormessage  @DTL_IS_VOID[gstk],":",  @DTL_NAME[gstk] 
         format gsttmp as gsttmp, STXT_VOID, "  "
         break
      endif
   endfor
   
   for gstk = 1 to N_STXT_DTLS
      if STX_USED[gstk] = 1
         format gsttmp as gsttmp, STXT_DTL_TAGS[gstk], " "
      endif
   endfor
   
   gst_sum_line = gsttmp

   //errormessage gsttmp

endsub

// ---------------------------------------------------------
// Read IV Parameters from text file
// ---------------------------------------------------------
sub read_text_params 
   var atmp : A256 = ""
   var rip_tag : A256 = ""
   var rip_value : A256 = ""
   var fn : N12 = 0
   var rop_i : N12 = 0
   var rop_x : N9
   var a[128] : A5
   var ntmp : N9

   // Lets skip this if we already have our parameters.
   // This will mean that a reboot may be needed to refresh
   // these params after they are changed...
   //
   fopen fn, "\cf\micros\etc\iv3700_params.txt", READ
   if fn <= 0
      fopen fn, "iv3700_params.txt", READ
   endif
   if fn <= 0
      errormessage "Error reading iv3700_params.txt"
      exitcontinue
   endif

   cleararray WsList
   Nws = 0
   N_STXT_DTLS = 0

   while not feof(fn)
      freadln fn, atmp

      if trim(atmp) = ""
         break
      endif

      hFS = "="
      split atmp, hFS, rip_tag, rip_value
      // errormessage rip_tag, ":", rip_value
      if trim(rip_tag) = "TXT_SUBTTL"
         TXT_SUBTTL = trim(rip_value)
      elseif trim(rip_tag) = "TXT_TAXTTL"
         TXT_TAXTTL = trim(rip_value)
      elseif trim(rip_tag) = "TXT_DSCTTL"
         TXT_DSCTTL = trim(rip_value)
      elseif trim(rip_tag) = "TXT_SVCTTL"
         TXT_SVCTTL = trim(rip_value)
      elseif trim(rip_tag) = "TXT_PMTTTL"
         TXT_PMTTTL = trim(rip_value)
      elseif trim(rip_tag) = "TXT_COVERS"
         TXT_COVERS = trim(rip_value)
      elseif trim(rip_tag) = "TXT_TABLE"
         TXT_TABLE = trim(rip_value)
      elseif trim(rip_tag) = "TXT_CHECK"
         TXT_CHECK = trim(rip_value)
      elseif trim(rip_tag) = "TXT_CHANGEDUE"
         TXT_CHANGEDUE = trim(rip_value)
      elseif trim(rip_tag) = "TXT_CHGTIP"
         TXT_CHGTIP = trim(rip_value)
      elseif trim(rip_tag) = "TXT_SI1"
         TXT_SI[1] = trim(rip_value)
      elseif trim(rip_tag) = "TXT_SI2"
         TXT_SI[2] = trim(rip_value)
      elseif trim(rip_tag) = "TXT_SI3"
         TXT_SI[3] = trim(rip_value)
      elseif trim(rip_tag) = "TXT_SI4"
         TXT_SI[4] = trim(rip_value)
      elseif trim(rip_tag) = "TXT_SI5"
         TXT_SI[5] = trim(rip_value)
      elseif trim(rip_tag) = "TXT_SI6"
         TXT_SI[6] = trim(rip_value)
      elseif trim(rip_tag) = "TXT_SI7"
         TXT_SI[7] = trim(rip_value)
      elseif trim(rip_tag) = "TXT_SI8"
         TXT_SI[8] = trim(rip_value)
      elseif trim(rip_tag) = "TXT_TAX1"
         TXT_TAX[1] = trim(rip_value)
      elseif trim(rip_tag) = "TXT_TAX2"
         TXT_TAX[2] = trim(rip_value)
      elseif trim(rip_tag) = "TXT_TAX3"
         TXT_TAX[3] = trim(rip_value)
      elseif trim(rip_tag) = "TXT_TAX4"
         TXT_TAX[4] = trim(rip_value)
      elseif trim(rip_tag) = "TXT_TAX5"
         TXT_TAX[5] = trim(rip_value)
      elseif trim(rip_tag) = "TXT_TAX6"
         TXT_TAX[6] = trim(rip_value)
      elseif trim(rip_tag) = "TXT_TAX7"
         TXT_TAX[7] = trim(rip_value)
      elseif trim(rip_tag) = "TXT_TAX8"
         TXT_TAX[8] = trim(rip_value)

      elseif trim(rip_tag) = "STXT_EMP_PRE"
         STXT_EMP_PRE = trim(rip_value)
      elseif trim(rip_tag) = "STXT_VOID"
         STXT_VOID = trim(rip_value)
      elseif trim(rip_tag) = "STXT_EVOID"
         STXT_EVOID = trim(rip_value)
      elseif trim(rip_tag) = "STXT_CANCEL"
         STXT_CANCEL = trim(rip_value)
      elseif trim(rip_tag) = "STXT_NOSALE"
         STXT_NOSALE = trim(rip_value)
      elseif trim(rip_tag) = "STXT_DTL_TAG"
	 N_STXT_DTLS = N_STXT_DTLS + 1
         split trim(rip_value), "|",  STXT_DTL_NAMES[N_STXT_DTLS],  STXT_DTL_TAGS[N_STXT_DTLS]

      elseif trim(rip_tag) = "HAS_INEDIT"
         HAS_INEDIT = trim(rip_value)
      elseif trim(rip_tag) = "HAS_INREOPEN"
         HAS_INREOPEN = trim(rip_value)
      elseif trim(rip_tag) = "HAS_VOIDSTATUS"
         HAS_VOIDSTATUS = trim(rip_value)
      elseif trim(rip_tag) = "HAS_CHGTIP"
         HAS_CHGTIP = trim(rip_value)
      elseif trim(rip_tag) = "UWS"
	 Nws = Nws + 1
         WsList[Nws] = trim(rip_value)
      endif

   endwhile

   fclose (fn)

endsub

// If we are on the UWS to monitor list, keep going,
// otherwise, exitcontinue...
sub check_uws 
   var cwi : N9

   call read_odbc_params

   if Nws <= 0 
      call read_text_params 
   endif

   if Nws <= 0 
      exitcontinue
   endif

   for cwi=1 to Nws
     if @WSID = WsList[cwi]
        return
     endif
   endfor
   
   // We are not processing.  Just move on.
   exitcontinue
endsub

// ---------------------------------------------------------
// Read Employee Names (to support pre-@TREMP_LNAME variables....)
// This one takes empobj as 1st parameter
// ---------------------------------------------------------
sub read_ename_obj (var thisemp : N9, ref re_stat, ref re_lname, ref re_fname, ref re_chkname)
   // this is to insert a tag for the name.  The server now inserts the name...
   format re_lname as "<<LNAME", @TREMP{09}
   format re_fname as "<<FNAME", @TREMP{09}
   format re_chkname as "<<CNAME", @TREMP{09}
   G_CurrentEmp = @TREMP
   G_CurrentELname = re_lname
   G_CurrentEFname = re_fname
   G_CurrentChkname = re_chkname
   re_stat = 1
   return

endsub


// ---------------------------------------------------------
// Read Employee OBJ and  Names (to support pre-@TREMP_LNAME variables....)
// This one takes empid as 1st parameter
// ---------------------------------------------------------
sub read_ename_id (var thisemp : A20, ref re_stat, ref re_lname, ref re_fname, ref re_empnum, ref re_chkname)

   var re_result : A8192 = ""
   var re_query : A1024 = ""
   var re_i : N9 = 0

   call init_odbc (re_stat)
   if re_stat < 0 
      return
   endif
   
   format re_query as "select obj_num, last_name, first_name, chk_name from micros.emp_def where id = ", trim(thisemp)
   // call dsp_message ("Query", re_query)
   call run_query (re_query, re_stat, re_result)
   // Single row returned....
   call run_fetch (re_stat, re_result)
   // call close_odbc 

      if trim(re_result) = ""
         re_lname = "Unknown"
         re_fname = "Employee"
         re_empnum = 0
         re_chkname = "Unknown"
         G_CurrentEmp = re_empnum
         G_CurrentELname = re_lname
         G_CurrentEFname = re_fname
         G_CurrentChkname = re_chkname
      else
         split re_result, hFS, re_empnum, re_lname, re_fname, re_chkname
         G_CurrentEmp = re_empnum
         G_CurrentELname = re_lname
         G_CurrentEFname = re_fname
         G_CurrentChkname = re_chkname
      endif
   call close_odbc
   
endsub

// ---------------------------------------------------------
// Read RVC Name
// ---------------------------------------------------------
sub read_rvcname (ref re_stat, ref re_rvcname, ref re_rvcseq)

   format re_rvcname as "<<RVCNAME", @RVC{09}
   re_stat = 1
   return
   
endsub

// ---------------------------------------------------------
// Read Table 
// ---------------------------------------------------------
sub read_table (var re_rvc_seq : N9, ref re_stat, ref re_table)
   // TBLNUM is actually the sequence... afu
   format re_table as "<<TABLE",  @TBLNUM{09},@RVC{09}
   re_stat = 1
   return

endsub

// ---------------------------------------------------------
// Read Tenders that will be done via inquires
// ---------------------------------------------------------
sub read_inq_tmed (var rit_idx : N9, ref rit_stat, ref rit_tmed, ref rit_tmedname)
   var rit_result : A8192 = ""
   var rit_query : A1024 = ""
   var rit_i : N9 = 0

   call init_odbc (rit_stat)
   if rit_stat < 0 
      return
   endif
   
   format rit_query as "select tmed_obj, tmed_name from imagevault_tmeds where tmed_idx = ", rit_idx
   //call dsp_message ("Query", rit_query)
   call run_query (rit_query, rit_stat, rit_result)
   // Single row returned....
      call run_fetch (rit_stat, rit_result)

      if trim(rit_result) = ""
         rit_tmedname = ""
         rit_tmed = 0
      else
         split rit_result, hFS, rit_tmed, rit_tmedname
      endif
   
   // call close_odbc 
   call close_odbc

endsub

// =========================================================
// ODBC Dll Routines...
// =========================================================
sub init_odbc (ref mystat)

   var stat : A1024 = ""
   var result : A1024 = ""
   var query : A1024 = ""
   var atmp: A1024 = ""
   var mycmd: A1024 = ""
   
   mystat = 0
   DLL_GOT_FIRST = 0
   
   if USE_BPSQL > 0
      if hDLL = 0
         DLLLOAD hDLL, "bpsql.dll"
         if hDLL = 0
            DLLLOAD hDLL, "bpsql.dll"
            if hDLL = 0
               errormessage "bpsql.dll cannot load"
	       mystat = -1
	       return
	    endif
         endif  
	 
         stat = ""
         result = ""
         query = ""

	 if G_DidInit = 1
	    mystat = 1
	    return
	 endif

         format mycmd as "DSN=micros;UID=", DBUser, ";PWD=", DBPwd, ";ServerName=",DBName 
         
	 if PRE_32 = 0
  	    DLLCALL_CDECL hDLL, _BPSQL_Func(ref mycmd, ref BPSQL_Init, ref query, ref stat, ref result)
	 else
 	    DLLCALL hDLL, _BPSQL_Func(ref mycmd, ref BPSQL_Init, ref query, ref stat, ref result)
	 endif
         if stat <> "0"
	    format atmp as stat, ": ", result
            call dsp_message ("Error", atmp)
	    mystat = -2
	    return
         endif
      endif

   else // using Micros ODBC..
      // new approach
     
     //errormessage "initializing ODBC: ", hDLL, ":", constatus
     
      if hDLL = 0
         DLLLOAD hDLL, "MDSSysUtilsProxy.dll"
         if hDLL = 0
            errormessage "Unable to Load MDSSysUtilsProxy.dll"
	    mystat = -2
	    return
         endif
      endif
      if constatus <= 0
         constatus = 0
         DLLCALL_CDECL hDLL, sqlIsConnectionOpen(ref constatus)
     //errormessage "Checking ODBC: ", hDLL, ":", constatus
         if constatus = 0
            format mycmd as "UID=", DBUser, ";PWD=", DBPwd 
            // DLLCALL_CDECL hDLL, sqlInitConnection("micros","ODBC;UID=custom;PWD=custom")
	    // errormessage mycmd
            DLLCALL_CDECL hDLL, sqlInitConnection("micros",mycmd)
     //errormessage "Checking ODBC Again: ", hDLL, ":", constatus
            DLLCALL_CDECL hDLL, sqlIsConnectionOpen(ref constatus)
	    if constatus <= 0
	       errormessage "Initialized Connection: ", constatus
	       mystat = -1
	       return
	    endif
	 endif
     // errormessage "Checking ODBC Last: ", hDLL, ":", constatus
         mystat = 1
         return
      else
         mystat = 1
         return
      endif
      
   endif

   G_DidInit = 1
   mystat = 1

endsub
sub close_odbc

   var stat : A1024 = ""
   var result : A1024 = ""
   var query : A1024 = ""
   var atmp: A1024 = ""
   
   DLL_GOT_FIRST = 0

   if USE_BPSQL > 0
      if hDLL <> 0
	 if PRE_32 = 0
  	    DLLCALL_CDECL hDLL, _BPSQL_Func(ref LICENSE, ref BPSQL_Close, ref query, ref stat, ref result)
	 else
 	    DLLCALL hDLL, _BPSQL_Func(ref LICENSE, ref BPSQL_Close, ref query, ref stat, ref result)
	 endif
         DLLFREE hDLL
	 hDLL = 0
         if stat <> "0"
	    format atmp as stat, ": ", result
            call dsp_message ("Error", atmp)
	    mystat = -2
	    return
         endif

      endif

   else // we are using Micros ODBC...
      // if hDLL <> 0 and constatus > 0
      if hDLL <> 0 
         DLLCALL_CDECL hDLL, sqlCloseConnection()
      endif
   endif // if use_bpsql
   
   constatus = 0

   G_DidInit = 0

endsub

sub run_query (ref myquery, ref mystat, ref myresult)
   var rq_stat : A80 = ""

   DLL_GOT_FIRST = 0

   if hDLL = 0
      errormessage "ODBC Not Initialized"
      mystat = -1
      return
   endif
      
   if USE_BPSQL > 0
      hFS = ";"
      if PRE_32 = 0
         DLLCALL_CDECL hDLL, \
            _BPSQL_Func(ref LICENSE, ref BPSQL_Query, ref myquery, ref rq_stat, ref myresult)
      else
         DLLCALL hDLL, \
            _BPSQL_Func(ref LICENSE, ref BPSQL_Query, ref myquery, ref rq_stat, ref myresult)
      endif
      if rq_stat <> "0"
	    format atmp as cq_stat, ": ", myresult
            call dsp_message ("Error", atmp)
	    mystat = rq_stat
	    return
      endif
   else // Micros DLL
      hFS = ";"
      DLLCALL_CDECL hDLL, sqlGetRecordSet(ref myquery)
      if myquery = ""
         DLLCALL_CDECL hDLL, sqlGetLastErrorString(ref myquery)
      if (myquery <> "" )
            call dsp_message ("Error", myquery)
	    mystat = -5
	    return
      endif
   endif

   mystat = 1


   return

endsub
sub run_fetch (ref mystat, ref myresult)
   // returns mystat = 0 for no data,
   // mystat = 1 for data
   // mystat = -x for errors

   var rf_atmp : A256   
   var rf_mystat : A1024
   var rf_myresult : A16384
   var rf_i : N9

   if hDLL = 0
      errormessage "ODBC Not Initialized"
      mystat = -1
      return
   endif

   if USE_BPSQL > 0
      hFS = ";"
         mystat = 0
	 rf_myresult = ""
	 rf_mystat = ""

            if PRE_32 = 0
               DLLCALL_CDECL hDLL, \
                  _BPSQL_Func(ref LICENSE, ref BPSQL_Fetch, ref rf_atmp, ref rf_mystat, ref rf_myresult)
            else
               DLCALL hDLL, \
                  _BPSQL_Func(ref LICENSE, ref BPSQL_Fetch, ref rf_atmp, ref rf_mystat, ref rf_myresult)
	    endif

	    // errormessage rf_mystat, ": ", mid(rf_myresult,1,30)
            if rf_mystat <> "0" 
	       mystat = rf_mystat
	       myresult = rf_myresult
	       return
            endif
	    mystat = 1
	    myresult = rf_myresult
	    return
   else
      hFS = ";"
      if DLL_GOT_FIRST <= 0
         DLLCALL_CDECL hDLL, sqlGetFirst(ref rf_myresult)
      else
         DLLCALL_CDECL hDLL, sqlGetNext(ref rf_myresult)
      endif
      DLL_GOT_FIRST = 1
      if rf_myresult = ""
	 mystat = 0
	 myresult = ""
      else
         myresult = rf_myresult
	 mystat = 1
      endif
      return

   endif

endsub
sub send_msg (var lf_bef : N9, var lf_aft : N9, ref sm_text[], var ntext:N9, ref sm_stat, ref sm_result)
   var atmp : A2048
   var sm_query : A2048 = ""
   var stat_query : A2048 = ""
   var smi : N9 

   DLL_GOT_FIRST = 0

   if hDLL = 0
      errormessage "ODBC Not Initialized"
      sm_stat = -1
      return
   endif

// select * from imagevault_data;
// Insert into ImageVault_Data (uws, text_message, pre_lf, post_lf, in_time) 
// select 2,'Msg2',0,0,Now()
// union
// select 3,'Msg3',0,0,Now()
      
   var sm_start_idx : N9 = 1
   var sm_end_idx : N9 = ntext
   var byby : N9 = 0
   var step_size : N9 = 20
   var xxi : N9 = 0
   var xpos : N9 = 0
   var xatmp : A1025 = ""


   for sm_start_idx=1 to ntext step step_size
	 sm_end_idx = sm_start_idx + step_size-1
	 if sm_start_idx + step_size >  ntext
	    sm_end_idx = ntext
	 endif

         format sm_query as "Insert into ImageVault_Data (uws, text_message, pre_lf, post_lf, in_time) "
         for smi = sm_start_idx to sm_end_idx
            if smi > ntext
	       byby = 1
               break
            endif

            // ---------------------------------------------------------------------------
	    // Strip out the pesky special SQL charcters...
            // ---------------------------------------------------------------------------
	    for xxi=1 to len(sm_text[smi])
	        xpos = instr(1, sm_text[smi], chr(34))
		if xpos > 0
		   format xatmp as mid(sm_text[smi],1, xpos-1) 
		   format xatmp as xatmp, mid(sm_text[smi],xpos+1, len(sm_text[smi]))
		   sm_text[smi] = xatmp
		else
		   break
		endif
	    endfor
	    for xxi=1 to len(sm_text[smi])
	        xpos = instr(1, sm_text[smi], ",")
		if xpos > 0
		   format xatmp as mid(sm_text[smi],1, xpos-1) 
		   format xatmp as xatmp, mid(sm_text[smi],xpos+1, len(sm_text[smi]))
		   sm_text[smi] = xatmp
		else
		   break
		endif
	    endfor
	    for xxi=1 to len(sm_text[smi])
	        xpos = instr(1, sm_text[smi], "'")
		if xpos > 0
		   format xatmp as mid(sm_text[smi],1, xpos-1) 
		   format xatmp as xatmp, mid(sm_text[smi],xpos+1, len(sm_text[smi]))
		   sm_text[smi] = xatmp
		else
		   break
		endif
	    endfor
            // ---------------------------------------------------------------------------

            // if smi > sm_start_idx and smi+1 <= sm_end_idx
            if smi > sm_start_idx 
                  format sm_query as sm_query," union "
            endif
            format sm_query as sm_query," select "
            format sm_query as sm_query, @WSID, ",'"
            format sm_query as sm_query, sm_text[smi], "', "
            format sm_query as sm_query, lf_bef, ", "
            format sm_query as sm_query, lf_aft, ", "
            format sm_query as sm_query, " Now() "
         endfor
	    
         format sm_query as sm_query, "; commit; "
   
         sm_stat = ""
         sm_result = ""

         if USE_BPSQL > 0
            if PRE_32 = 0
                     DLLCALL_CDECL hDLL, \
                        _BPSQL_Func(ref LICENSE, ref BPSQL_Query, ref sm_query, ref sm_stat, ref sm_result)
            else
                     DLCALL hDLL, \
                        _BPSQL_Func(ref LICENSE, ref BPSQL_Query, ref sm_query, ref sm_stat, ref sm_result)
            endif
            if sm_stat <> "0"
	          format atmp as sm_stat, ": ",sm_result
                  call dsp_message ("Error", atmp)
	          return
            endif

            // Update the status table
            format stat_query as "update imagevault_status set hasdata = 1"
            if PRE_32 = 0
                     DLLCALL_CDECL hDLL, \
                        _BPSQL_Func(ref LICENSE, ref BPSQL_Query, ref stat_query, ref sm_stat, ref sm_result)
            else
                     DLCALL hDLL, \
                        _BPSQL_Func(ref LICENSE, ref BPSQL_Query, ref stat_query, ref sm_stat, ref sm_result)
            endif
            if sm_stat <> "0"
	          format atmp as sm_stat, ": ",sm_result
                  call dsp_message ("Error", atmp)
	          return
            endif

         else
            // call dsp_message ("Query", sm_query)
            DLLCALL_CDECL hDLL, sqlExecuteQuery (sm_query);
            // call dsp_message ("Result", sm_query)

            DLLCALL_CDECL hDLL, sqlGetLastErrorString(ref sm_query)
            if sm_query <> "" 
                  call dsp_message ("Error", sm_query)
	          sm_stat = -5
	          break
            else
               format stat_query as "update imagevault_status set hasdata = 1"
               DLLCALL_CDECL hDLL, sqlExecuteQuery (stat_query);
               DLLCALL_CDECL hDLL, sqlGetLastErrorString(ref sm_query)
               if trim(sm_query) <> ""
                  call dsp_message ("Error", sm_query)
	          sm_stat = -5
	          break
               else
	          sm_stat = 1
	          // return
               endif
            endif
         endif
   	
      if byby > 0
	    break
      endif

   endfor 
   return

endsub
 
sub is_timeout(var tmp : N9)
endsub

sub update_check_flags (var mychkkey : A128) 
   var atmp : A2048
   var uc_query : A2048 = ""
   var uc_stat : A2048 = ""
   var uc_result : A2048 = ""
   var stat_query : A2048 = ""
   var smi : N9 
  
  // DB Needs to be open already on this one...

      uc_query = "insert into imagevault_check_flags (in_time, check_key, has_ec) "
      format uc_query as uc_query, "values (Now(),'", mychkkey, "', 1) "
   
         if USE_BPSQL > 0
            if PRE_32 = 0
                     DLLCALL_CDECL hDLL, \
                        _BPSQL_Func(ref LICENSE, ref BPSQL_Query, ref uc_query, ref uc_stat, ref uc_result)
            else
                     DLCALL hDLL, \
                        _BPSQL_Func(ref LICENSE, ref BPSQL_Query, ref uc_query, ref uc_stat, ref uc_result)
            endif
            if uc_stat <> "0"
	          format atmp as uc_stat, ": ",uc_result
                  call dsp_message ("Error", atmp)
	          return
            endif

         else
            // call dsp_message ("Query", uc_query)
            DLLCALL_CDECL hDLL, sqlExecuteQuery (uc_query);
            //call dsp_message ("Query", uc_query)
            DLLCALL_CDECL hDLL, sqlGetLastErrorString(ref uc_query)
            if uc_query <> "" 
                  call dsp_message ("Error", uc_query)
	          uc_stat = -5
	          return
            endif
         endif
endsub

sub check_if_ec (var mycheckkey : A128, ref myhasec)
   var atmp : A2048
   var ci_query : A2048 = ""
   var ci_stat : A2048 = ""
   var ci_result : A2048 = ""
   var stat_query : A2048 = ""
   var ci : N9 

   myhasec = 0

   // call init_odbc (ci_stat)
   // if ci_stat < 0 
   //    return
   // endif
   
   format ci_query as "select has_ec from imagevault_check_flags where check_key = '", mycheckkey, "' "
   // call dsp_message ("Query", ci_query)
   call run_query (ci_query, ci_stat, ci_result)
   // Single row returned....
   call run_fetch (ci_stat, ci_result)

   if trim(ci_result) = ""
         return
   else
         split ci_result, hFS, myhasec
   endif
   
   myhasec = 1

   // errormessage mycheckkey, ":", myhasec

endsub
sub dsp_message (var dmi_title:A40, ref dmi_msg)
   var dmi : N9 = 0

   window 12, 50, dmi_title
   for dmi=0 to 11
      if trim(mid(dmi_msg, 40*dmi + 1, 40)) <> ""
         display dmi+1, 1, mid(dmi_msg, 40*dmi + 1, 40)
      else
         break
      endif
      
   endfor
   waitforconfirm

   return   
endsub


// ---------------------------------------------------------
// Read ODBC Parameters from text file
// ---------------------------------------------------------
sub read_odbc_params 
   var atmp : A8192 = ""
   var fn : N12 = 0
   var rop_i : N12 = 0
   var rop_x : N9
   var a[128] : A5
   var ntmp : N9

   // Lets skip this if we already have our parameters.
   // This will mean that a reboot may be needed to refresh
   // these params after they are changed...
   //
   
   if READ_PFILE_ALWAYS = 0
      if trim(DBUser) <> "" and trim(DBPwd) <> "" 
         return
      endif
   endif

   fopen fn, "\cf\micros\etc\iv3700_user.dat", READ
   if fn <= 0
      fopen fn, "iv3700_user.dat", READ
   endif
   if fn <= 0
      errormessage "Error reading iv3700_user.dat"
      exitcontinue
   endif

   USE_BPSQL = 0
   PRE_32 = 0
   rop_i = 1

   DBUser = ""
   DBPwd = ""
   DBPwdEnc = ""

   while not feof(fn)
      freadln fn, atmp

      if trim(atmp) = ""
         break
      endif

      if rop_i = 1
	 if trim(atmp) = "USE_BPSQL"
            USE_BPSQL = 1
	 endif
      elseif rop_i = 2
	 if trim(atmp) = "PRE_32"
            PRE_32 = 1
	 endif
     elseif rop_i = 3
         DBName = trim(atmp)
      elseif rop_i = 4
         DBUser = trim(atmp)
      elseif rop_i = 5
         DBPwdEnc = trim(atmp)
      endif
      
      rop_i = rop_i + 1
   endwhile

   fclose (fn)

   // Figure out the db password
   a[1] = "M"
   a[2] = "N"
   a[3] = "B"
   a[4] = "V"
   a[5] = "C"
   a[6] = "X"
   a[7] = "Z"

   a[8] = "L"
   a[9] = "K"
   a[10] = "J"
   a[11] = "H"
   a[12] = "G"
   a[13] = "F"
   a[14] = "D"
   a[15] = "S"
   a[16] = "A"
     
   a[17] = "P"
   a[18] = "O"
   a[19] = "I"
   a[20] = "U"
   a[21] = "Y"
   a[22] = "T"
   a[23] = "R"
   a[24] = "E"
   a[25] = "W"
   a[26] = "Q"
     
   a[27] = "0"
   a[28] = "9"
   a[29] = "8"
   a[30] = "7"
   a[31] = "6"
   a[32] = "5"
   a[33] = "4"
   a[34] = "3"
   a[35] = "2"
   a[36] = "1"
   
   a[37] = "`"
   a[38] = "-"
   a[39] = "="
   a[40] = "["
   a[41] = "]"
   a[42] = ";"
   a[43] = "'"
   a[44] = ","
   a[45] = "."
   a[46] = "/"
   a[47] = "\"

   a[48] = "m"
   a[49] = "n"
   a[50] = "b"
   a[51] = "v"
   a[52] = "c"
   a[53] = "x"
   a[54] = "z"

   a[55] = "l"
   a[56] = "k"
   a[57] = "j"
   a[58] = "h"
   a[59] = "g"
   a[60] = "f"
   a[61] = "d"
   a[62] = "s"
   a[63] = "a"
     
   a[64] = "p"
   a[65] = "o"
   a[66] = "i"
   a[67] = "u"
   a[68] = "y"
   a[69] = "t"
   a[70] = "r"
   a[71] = "e"
   a[72] = "w"
   a[73] = "q"

     
   a[74] = "%"
   a[75] = "~"
   a[76] = "_"
   a[77] = "+"
   a[78] = "{"
   a[79] = "}"
   a[80] = "|"
   a[81] = ":"
   a[82] = chr(34)
   a[83] = "<"
   a[84] = ">"
   a[85] = "?"

  for rop_x = 1 to len(DBPwdEnc) step 2
     atmp = mid(DBPwdEnc, rop_x, 2)
     ntmp = GetHex(atmp) + 1	
     // errormessage "Convert: ", atmp, ":", ntmp, ":", a[ntmp]
     if ntmp > 0 and ntmp < 128
        format DBPwd as DBPwd, a[ntmp]
     endif
  endfor

  // errormessage USE_BPSQL, ":", PRE_32, ":", DBUser, ":", DBPwd


endsub

sub set_dtl_name (var myobj : N9, var mylvl : N9, var myrvc : N9, ref mystring)

   //errormessage myobj{09}, ":", myrvc{09}, ":", mylvl{02}
   format mystring as "<<MIDEF", myobj{09}, myrvc{09}, mylvl{02}
   // errormessage "(", mystring, ")"
   return

endsub

sub check_server_mode
   if @instandalonemode > 0 OR @InBackupMode > 0
      exitcontinue
   endif
endsub


 