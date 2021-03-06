# Prog. Version..: '5.25.02-11.03.23(00010)'     #123
#
# Program name...: scsft621hcsub_sub.4gl
# Description....: 提供scsft621hc.src.4gl使用的sub routine
# Date & Author..: 11/08/31 By CMP.Jiunn
# Memo...........: Copy By sasft621hc_sub.4gl
# Memo...........: 因110906版更patch第二、三包調整
# Modify.........: 15/2/6 Add By Emily.Lin 導入條碼 
#151203 BY CMP.MaX 確認後不再刪除tc_bar_tmp_file，新增tc_bas_file，因為確認不確認皆可補標籤
#151204 BY CMP.MaX 改為過帳後更新tc_bar_file標籤狀態
#161021 BY CMP.MaX 增加判斷完工入庫誤差率，允許超入
#180731 BY CMP.Geoffrey 增加自動開立 - 加工工單、發料單功能
#180805 BY CMP.Geoffrey 增加還原開立 - 加工工單、發料單功能

XXX
DATABASE ds
 
GLOBALS "../../../tiptop/config/top.global"
GLOBALS "../4gl/scsft621hc.global"

GLOBALS
DEFINE g_unit_arr      DYNAMIC ARRAY OF RECORD  #No.FUN-610090          #NO.FUN-9B0016        
                          unit   LIKE ima_file.ima25,                           
                          fac    LIKE img_file.img21,                           
                          qty    LIKE img_file.img10                            
                       END RECORD                                               
END GLOBALS 
DEFINE g_forupd_sql STRING
#180731 BY CMP.Geoffrey Add (S)
DEFINE gi_err_code     STRING
#DEFINE g_sfb           RECORD LIKE sfb_file.*
DEFINE g_sfa           RECORD LIKE sfa_file.*,
       g_sfa2          RECORD LIKE sfa_file.*,
       g_img           RECORD LIKE img_file.*
DEFINE g_data_cnt      LIKE type_file.num5,
       part_type       LIKE type_file.chr1,
       noqty           LIKE type_file.chr1,
       short_data      LIKE type_file.chr1,
       issue_type      LIKE type_file.chr1,
       ware_no         LIKE img_file.img02,
       loc_no          LIKE img_file.img03,
       lot_no          LIKE img_file.img04,
       g_ima108        LIKE ima_file.ima108,
       img_qty         LIKE sfb_file.sfb08,       
       qty_alo         LIKE sfb_file.sfb08,
       g_msg           LIKE type_file.chr1000,
       g_msg4          STRING,
       issue_qty,issue_qty1,issue_qty2  LIKE sfb_file.sfb08,
       l_gen_YN        LIKE type_file.chr10
#180731 BY CMP.Geoffrey Add (E)

#作用:lock cursor
#回傳值:無

FUNCTION t621hcsub_lock_cl()
   LET g_forupd_sql = "SELECT * FROM sfu_file WHERE sfu01 = ? FOR UPDATE"
   LET g_forupd_sql = cl_forupd_sql(g_forupd_sql)
   DECLARE t621hcsub_cl CURSOR FROM g_forupd_sql
END FUNCTION
 
FUNCTION t621hcsub_y_chk(p_argv,p_sfu01)
   DEFINE p_argv     LIKE type_file.chr1      
   DEFINE p_sfu01    LIKE sfu_file.sfu01
   DEFINE l_sfu      RECORD LIKE sfu_file.*
   DEFINE l_sfv      RECORD LIKE sfv_file.*
   DEFINE l_cnt      LIKE type_file.num10 
   DEFINE l_str      STRING
   DEFINE l_imaicd08 LIKE imaicd_file.imaicd08  
   DEFINE l_flag     LIKE type_file.num10       
   DEFINE l_rvbs06   LIKE rvbs_file.rvbs06      
   DEFINE l_date     LIKE type_file.dat    
   DEFINE l_ima918   LIKE ima_file.ima918
   DEFINE l_ima921   LIKE ima_file.ima921   
   DEFINE l_img09    LIKE img_file.img09
   DEFINE l_sfb39    LIKE sfb_file.sfb39
   DEFINE l_i        LIKE type_file.num5
   DEFINE l_fac      LIKE ima_file.ima31_fac
   
   WHENEVER ERROR CONTINUE 
   
   LET g_success='Y'
   
   SELECT * INTO l_sfu.* FROM sfu_file WHERE sfu01=p_sfu01  
   IF cl_null(l_sfu.sfu01) THEN
      CALL cl_err('','-400',1)
      LET g_success='N'
      RETURN
   END IF
   
   LET l_cnt=0  
   SELECT COUNT(*) INTO l_cnt FROM sfv_file WHERE sfv01 = l_sfu.sfu01
   IF l_cnt = 0 THEN
      CALL cl_err(l_sfu.sfu01,'mfg-009',0) 
      LET g_success='N' 
      RETURN
   END IF
   #TQC-B30028--begin
   LET l_cnt=0 
   SELECT COUNT(*) INTO l_cnt FROM gem_file WHERE gem01=l_sfu.sfu04 AND gemacti='Y' 
   IF l_cnt=0 THEN 
      CALL cl_err('','asf-624',1)
      LET g_success='N'
      RETURN
   END IF 
   #TQC-B30028--end 
   IF l_sfu.sfuconf = 'Y' THEN
      LET g_success='N'
      CALL cl_err(l_sfu.sfu01,'9023',0)
      RETURN
   END IF
   
   IF l_sfu.sfuconf = 'X' THEN
      LET g_success='N' 
      CALL cl_err(l_sfu.sfu01,'9024',0) 
      RETURN
   END IF
 
   #Cehck 單身 料倉儲批是否存在 img_file
   DECLARE t621hcsub_y_chk_c CURSOR FOR SELECT * FROM sfv_file
                                   WHERE sfv01=l_sfu.sfu01
   FOREACH t621hcsub_y_chk_c INTO l_sfv.*
     #MOD-AC0389---add---start---
      IF NOT s_chksmz(l_sfv.sfv04, l_sfu.sfu01,
                      l_sfv.sfv05, l_sfv.sfv06) THEN
         LET g_success = 'N'
         EXIT FOREACH
      END IF
     #MOD-AC0389---add---end---
   
      #Add No.No.FUN-AB0054
      IF NOT s_chk_ware(l_sfv.sfv05) THEN  #检查仓库是否属于当前门店
         LET g_success='N'
         EXIT FOREACH
      END IF
      #End Add No.No.FUN-AB0054
      #-----No.FUN-860045 Begin-----
      SELECT ima918,ima921 INTO l_ima918,l_ima921 
        FROM ima_file
       WHERE ima01 = l_sfv.sfv04
         AND imaacti = "Y"
      
      IF l_ima918 = "Y" OR l_ima921 = "Y" THEN
         SELECT SUM(rvbs06) INTO l_rvbs06
           FROM rvbs_file
          WHERE rvbs00 = g_prog
            AND rvbs01 = l_sfv.sfv01
            AND rvbs02 = l_sfv.sfv03
            AND rvbs09 = 1
            AND rvbs13 = 0
            
         IF cl_null(l_rvbs06) THEN
            LET l_rvbs06 = 0
         END IF
            
         SELECT img09 INTO l_img09 FROM img_file
          WHERE img01=l_sfv.sfv04
            AND img02=l_sfv.sfv05
            AND img03=l_sfv.sfv06
            AND img04=l_sfv.sfv07
 
         CALL s_umfchk(l_sfv.sfv04,l_sfv.sfv08,l_img09) 
             RETURNING l_i,l_fac
 
         IF l_i = 1 THEN LET l_fac = 1 END IF
 
         IF (l_sfv.sfv09 * l_fac) <> l_rvbs06 THEN
            LET g_success = "N"
            CALL cl_err(l_sfv.sfv04,"aim-011",1)
            EXIT FOREACH
         END IF
      END IF
      #-----No.FUN-860045 END-----
 
      LET l_cnt=0
 
      SELECT COUNT(*) INTO l_cnt FROM img_file WHERE img01=l_sfv.sfv04
                                                 AND img02=l_sfv.sfv05
                                                 AND img03=l_sfv.sfv06
                                                 AND img04=l_sfv.sfv07
      IF l_cnt=0 THEN
         LET g_success='N'
         LET l_str="Item ",l_sfv.sfv03,":"
         CALL cl_err(l_str,'asf-507',1)
         EXIT FOREACH
      END IF
      
      #CHI-910027-begin-add
      SELECT sfb39 INTO l_sfb39 FROM sfb_file WHERE sfb01=l_sfv.sfv11
      IF l_sfb39 != '2' THEN
         #檢查工單最小發料日是否小於入庫日
         SELECT MIN(sfp03) INTO l_date FROM sfe_file,sfp_file  
          WHERE sfe01 = l_sfv.sfv11 AND sfe02 = sfp01
         IF STATUS OR cl_null(l_date) THEN
            SELECT MIN(sfp03) INTO l_date FROM sfs_file,sfp_file
             WHERE sfs03=l_sfv.sfv11 AND sfp01=sfs01
         END IF
       
         IF cl_null(l_date) OR l_date > l_sfu.sfu02 THEN
            LET g_success='N'   
            CALL cl_err(l_sfv.sfv11,'asf-824',1)
            EXIT FOREACH
         END IF
      END IF
      #CHI-910027-end-add
 
      IF s_industry('icd') THEN
         #No.FUN-830061  --BEGIN
         LET l_imaicd08 = NULL
         SELECT imaicd08 INTO l_imaicd08
           FROM imaicd_file WHERE imaicd00 =  l_sfv.sfv04
            
         IF l_imaicd08 = 'Y' THEN
            IF p_argv = '1' THEN
               CALL s_icdchk(1,l_sfv.sfv04,   #TQC-9C0091
                               l_sfv.sfv05,
                               l_sfv.sfv06,
                               l_sfv.sfv07,  
                               l_sfv.sfv09, 
                               l_sfu.sfu01,l_sfv.sfv03,
                               l_sfu.sfu02)
                    RETURNING l_flag
            ELSE  
               CALL s_icdchk(-1,l_sfv.sfv04,                                                                                      
                                l_sfv.sfv05,                                                                                      
                                l_sfv.sfv06,                                                                                      
                                l_sfv.sfv07,                                                                                      
                                l_sfv.sfv09,                                                                                      
                                l_sfu.sfu01,l_sfv.sfv03,                                                                          
                                l_sfu.sfu02)                                                                                            
                    RETURNING l_flag
            END IF
            IF l_flag = 0 THEN
               CALL cl_err(l_sfv.sfv03,'aic-056',1) 
               LET g_success = 'N' 
               EXIT FOREACH
            END IF
         END IF 
         #No.FUN-830061  --END
      END IF
 
   END FOREACH
      
   IF g_success = 'N' THEN RETURN END IF
 
END FUNCTION
 
 
#carrier Transaction is wrong & popup dialog,how to process
FUNCTION t621hcsub_y_upd(p_sfu01,p_action_choice,p_inTransaction)
   DEFINE p_sfu01          LIKE sfu_file.sfu01
   DEFINE p_action_choice  STRING
   DEFINE p_inTransaction  LIKE type_file.num5 
   DEFINE l_sfu            RECORD LIKE sfu_file.*
   DEFINE l_sfumksg        LIKE sfu_file.sfumksg  #FUN-A80128 add
   DEFINE l_sfu15          LIKE sfu_file.sfu15    #FUN-A80128 add
 
   LET g_success = 'Y'
 
   #FUN-A80128 add---str---
   IF p_action_choice CLIPPED = "confirm" OR #執行 "確認" 功能(非簽核模式呼叫)
      p_action_choice CLIPPED = "insert"     
   THEN 
      SELECT sfumksg,sfu15 
        INTO l_sfumksg,l_sfu15
        FROM sfu_file
       WHERE sfu01=p_sfu01
      IF l_sfumksg='Y' THEN #若簽核碼為 'Y' 且狀態碼不為 '1' 已同意
         IF l_sfu15 != '1' THEN
            CALL cl_err('','aws-078',1) #此狀況碼不為「1.已核准」，不可確認!!
            LET g_success = 'N'
            RETURN
         END IF
      END IF
   END IF
   #FUN-A80128 add---end---

   IF NOT cl_null(p_action_choice) THEN  #FUN-840012    #carrier
      IF p_action_choice <> 'efconfirm' THEN #FUN-A80128 add if 判斷
      IF NOT cl_confirm('axm-108') THEN RETURN END IF
      END IF                                 #FUN-A80128 add
   END IF
   
   IF cl_null(p_sfu01) THEN
      CALL cl_err('','-400',1)
      LET g_success='N'
      RETURN
   END IF

   IF NOT p_inTransaction THEN   
      BEGIN WORK    #carrier
   END IF
 
   CALL t621hcsub_lock_cl() 
   OPEN t621hcsub_cl USING p_sfu01
   IF STATUS THEN
      CALL cl_err("OPEN t621hcsub_cl:", STATUS, 1)
      CLOSE t621hcsub_cl
      IF NOT p_inTransaction THEN ROLLBACK WORK END IF
      LET g_success='N' #FUN-730012 add
      RETURN
   END IF
 
   FETCH t621hcsub_cl INTO l_sfu.*          # 鎖住將被更改或取消的資料
   IF SQLCA.sqlcode THEN
      CALL cl_err('lock sfu:',SQLCA.sqlcode,0)     # 資料被他人LOCK
      CLOSE t621hcsub_cl
      IF NOT p_inTransaction THEN ROLLBACK WORK END IF
      LET g_success='N' #FUN-730012 add
      RETURN
   END IF
 
   CLOSE t621hcsub_cl
#151203 BY CMP.MaX mark---(S)
#   #15/2/6 Add By Emily.Lin (S)
#   CALL t621hcsub_y_updb(l_sfu.sfu01) RETURNING g_success  # lgj审核时调用的标签存盘函数
#   IF g_success = 'N' THEN  # lgj存盘函数如果调用不成功，返回
#      ROLLBACK WORK 
#      LET g_success='N' #FUN-730012 add
#      RETURN
#   END IF   
#   #15/2/6 Add By Emily.Lin (E)
#151203 BY CMP.MaX mark---(E)
   UPDATE sfu_file SET sfuconf = 'Y',
                       sfu15 = '1'  #FUN-A80128 add
    WHERE sfu01=l_sfu.sfu01
   IF STATUS THEN
      CALL cl_err3("upd","sfu_file",l_sfu.sfu01,"",STATUS,"","upd sfuconf",1) 
      LET g_success='N'
   END IF
 
    #--FUN-8C0081--start--
    IF g_success='Y' THEN
       LET l_sfu.sfuconf = "Y"
       IF NOT p_inTransaction THEN COMMIT WORK END IF
       CALL cl_flow_notify(l_sfu.sfu01,'Y')
    ELSE
       LET l_sfu.sfuconf = "N"
       IF NOT p_inTransaction THEN ROLLBACK WORK END IF
    END IF
    #--FUN-8C0081--end--
END FUNCTION
 
FUNCTION t621hcsub_refresh(p_sfu01)
  DEFINE p_sfu01 LIKE sfu_file.sfu01
  DEFINE l_sfu RECORD LIKE sfu_file.*
 
  SELECT * INTO l_sfu.* FROM sfu_file WHERE sfu01=p_sfu01
  RETURN l_sfu.*
END FUNCTION
 
 
#carrier Transaction is wrong & popup dialog,how to process
FUNCTION t621hcsub_z(p_sfu01,p_action_choice,p_inTransaction)
   DEFINE p_sfu01          LIKE sfu_file.sfu01
   DEFINE p_action_choice  STRING
   DEFINE p_inTransaction  LIKE type_file.num5 
   DEFINE l_sfu            RECORD LIKE sfu_file.*
 
   LET g_success = 'Y'
 
   SELECT * INTO l_sfu.* FROM sfu_file WHERE sfu01=p_sfu01  
   IF cl_null(l_sfu.sfu01) THEN
      CALL cl_err('','-400',1)
      LET g_success='N'
      RETURN
   END IF
   
   IF l_sfu.sfuconf = 'N' THEN
      LET g_success='N'
      CALL cl_err(l_sfu.sfu01,'9025',0)
      RETURN
   END IF
   
   IF l_sfu.sfuconf = 'X' THEN
      LET g_success='N' 
      CALL cl_err(l_sfu.sfu01,'9024',0) 
      RETURN
   END IF   
   
   IF l_sfu.sfupost = 'Y' THEN
      LET g_success='N' 
      CALL cl_err(l_sfu.sfu01,'afa-106',0) 
      RETURN
   END IF   
 
   IF NOT cl_null(p_action_choice) THEN
      IF NOT cl_confirm('axm-109') THEN RETURN END IF
   END IF
   
   IF NOT p_inTransaction THEN 
      BEGIN WORK    #carrier
   END IF
 
   CALL t621hcsub_lock_cl() #FUN-730012
   OPEN t621hcsub_cl USING l_sfu.sfu01
   IF STATUS THEN
      CALL cl_err("OPEN t621hcsub_cl:", STATUS, 1)
      CLOSE t621hcsub_cl
      IF NOT p_inTransaction THEN ROLLBACK WORK END IF
      LET g_success='N' 
      RETURN
   END IF
 
   FETCH t621hcsub_cl INTO l_sfu.*          # 鎖住將被更改或取消的資料
   IF SQLCA.sqlcode THEN
      CALL cl_err('lock sfu:',SQLCA.sqlcode,0)     # 資料被他人LOCK
      CLOSE t621hcsub_cl
      IF NOT p_inTransaction THEN ROLLBACK WORK END IF
      LET g_success='N' 
      RETURN
   END IF
   
   CLOSE t621hcsub_cl
   #15/2/6 Add By Emily.Lin (S)
   CALL t621hcsub_n_updb(l_sfu.sfu01) RETURNING g_success  # lgj审核时调用的标签存盘函数
   IF g_success = 'N' THEN  # lgj存盘函数如果调用不成功，返回
      ROLLBACK WORK 
      LET g_success='N' #FUN-730012 add
      RETURN
   END IF   
   #15/2/6 Add By Emily.Lin (E)
   UPDATE sfu_file SET sfuconf = 'N',
                       sfu15 = '0'  #FUN-A80128 add
    WHERE sfu01=l_sfu.sfu01
   IF STATUS THEN
      CALL cl_err3("upd","sfu_file",l_sfu.sfu01,"",STATUS,"","upd sfuconf",1) 
      LET g_success='N'
   END IF
 
    #--FUN-8C0081--start--
    IF g_success='Y' THEN
       LET l_sfu.sfuconf = "N"
       LET l_sfu.sfu15='0'                       #FUN-A80128 add
       IF NOT p_inTransaction THEN COMMIT WORK END IF
    ELSE
       LET l_sfu.sfuconf = "Y"
       LET l_sfu.sfu15='1'                       #FUN-A80128 add
       IF NOT p_inTransaction THEN ROLLBACK WORK END IF
    END IF
    #--FUN-8C0081--end--
END FUNCTION
 
 
#p_argv1 : #1.發料 2.退料 #TQC-890051
#p_inTransaction : IF p_inTransaction=FALSE 會在程式中呼叫BEGIN WORK
#p_ask_post : IF p_ask_post=TRUE 會詢問"是否執行過帳"
FUNCTION t621hcsub_s(p_sfu01,p_argv,p_inTransaction,p_action_choice)
   DEFINE p_sfu01         LIKE sfu_file.sfu01
   DEFINE p_argv          LIKE type_file.chr1
   DEFINE p_inTransaction LIKE type_file.num5 
   DEFINE p_action_choice STRING   
   DEFINE l_sfu           RECORD LIKE sfu_file.*
   DEFINE l_cnt           LIKE type_file.num5 
   DEFINE l_yy            LIKE type_file.num5
   DEFINE l_mm            LIKE type_file.num5
   DEFINE l_sfu03         LIKE sfu_file.sfu03  
   DEFINE lj_result       LIKE type_file.chr1  #No.FUN-930108 存s_incchk()返回值
   DEFINE l_sfv           RECORD LIKE sfv_file.*
   DEFINE l_sfu02         LIKE sfu_file.sfu02
 
   WHENEVER ERROR CONTINUE                #忽略一切錯誤  #FUN-740187
   
   LET g_success='Y' #FUN-740187
   
   IF s_shut(0) THEN LET g_success='N' RETURN END IF
 
   SELECT * INTO l_sfu.* FROM sfu_file WHERE sfu01=p_sfu01
 
   IF l_sfu.sfu01 IS NULL THEN
      CALL cl_err('',-400,0)
      LET g_success='N' RETURN
   END IF
 
   #FUN-660106...............begin
   IF l_sfu.sfuconf = 'N' THEN
      CALL cl_err('','aba-100',1)
      LET g_success='N' RETURN
   END IF
   #FUN-660106...............end
 
   #-->已扣帳
   IF l_sfu.sfupost = 'Y' THEN
      CALL cl_err('sfupost=Y','asf-812',1)
      LET g_success='N' RETURN
   END IF
 
   IF l_sfu.sfuconf = 'X' THEN  #FUN-660106
      CALL cl_err('','9024',1)
      LET g_success='N' RETURN
   END IF
 
   #-----No.FUN-930108--start-----
   DECLARE t621hcsub_s_c CURSOR FOR
     SELECT * FROM sfv_file WHERE sfv01=l_sfu.sfu01
 
   FOREACH t621hcsub_s_c INTO l_sfv.*
      IF cl_null(l_sfv.sfv04) THEN
         #LET g_success='N'
         CONTINUE FOREACH
      END IF
      CALL s_incchk(l_sfv.sfv05,l_sfv.sfv06,g_user)
           RETURNING  lj_result
      IF NOT lj_result THEN
         CALL cl_err(l_sfu.sfu01,'axm-399',1)
         LET g_success = 'N'                       #carrier add
         RETURN                                    #carrier check with douzh
      END IF
   END FOREACH
   #-----No.FUN930108---end------
   
   #FUN-860069
   LET l_sfu02 = l_sfu.sfu02
 
  #--------------------No:MOD-9A0018 add
   IF NOT p_inTransaction THEN
      BEGIN WORK
   END IF

   CALL t621hcsub_lock_cl() 
   OPEN t621hcsub_cl USING l_sfu.sfu01
   IF STATUS THEN
      CALL cl_err("OPEN t621hcsub_cl:", STATUS, 1)
      CLOSE t621hcsub_cl
      IF NOT p_inTransaction THEN ROLLBACK WORK END IF
      RETURN
   END IF
  #--------------------No:MOD-9A0018 end

   IF NOT cl_null(p_action_choice) THEN  #FUN-840012
      IF NOT cl_confirm('mfg0176') THEN 
         LET g_success='N' 
        #--------------No:MOD-9A0018  add
         CLOSE t621hcsub_cl
         IF NOT p_inTransaction THEN ROLLBACK WORK END IF
        #--------------No:MOD-9A0018  end
         RETURN 
      END IF
   END IF
   
   IF NOT cl_null(g_action_choice) THEN  #FUN-840012 外部呼叫時
      DISPLAY BY NAME l_sfu.sfu02
      INPUT BY NAME l_sfu.sfu02 WITHOUT DEFAULTS
      
           AFTER FIELD sfu02
               IF NOT cl_null(l_sfu.sfu02) THEN
                  IF g_sma.sma53 IS NOT NULL AND l_sfu.sfu02 <= g_sma.sma53 THEN
                     CALL cl_err('','mfg9999',0) 
                     NEXT FIELD sfu02
                  END IF
                  CALL s_yp(l_sfu.sfu02) RETURNING l_yy,l_mm
                  IF (l_yy*12+l_mm) > (g_sma.sma51*12+g_sma.sma52) THEN
                     CALL cl_err(l_yy,'mfg6090',0) 
                     NEXT FIELD sfu02
                  END IF
               END IF
               
           AFTER INPUT 
               IF INT_FLAG THEN
                  LET INT_FLAG = 0
                  LET l_sfu.sfu02=l_sfu02
                  DISPLAY BY NAME l_sfu.sfu02
                 #--------------No:MOD-9A0018  add
                  CLOSE t621hcsub_cl
                  IF NOT p_inTransaction THEN ROLLBACK WORK END IF
                 #--------------No:MOD-9A0018  end
                  RETURN
               END IF
               IF NOT cl_null(l_sfu.sfu02) THEN
                  IF g_sma.sma53 IS NOT NULL AND l_sfu.sfu02 <= g_sma.sma53 THEN
                     CALL cl_err('','mfg9999',0) 
                     NEXT FIELD sfu02
                  END IF
                  CALL s_yp(l_sfu.sfu02) RETURNING l_yy,l_mm
                  IF (l_yy*12+l_mm) > (g_sma.sma51*12+g_sma.sma52) THEN
                     CALL cl_err(l_yy,'mfg6090',0) 
                     NEXT FIELD sfu02
                  END IF
               ELSE
                  CONTINUE INPUT
               END IF
               
           ON ACTION CONTROLG 
              CALL cl_cmdask()
   
           ON IDLE g_idle_seconds
              CALL cl_on_idle()
              CONTINUE INPUT
      END INPUT
   END IF
   #--
 
   IF g_sma.sma53 IS NOT NULL AND l_sfu.sfu02 <= g_sma.sma53 THEN
      LET g_success = 'N'
      CALL cl_err('','mfg9999',0) 
     #--------------No:MOD-9A0018  add
      CLOSE t621hcsub_cl
      IF NOT p_inTransaction THEN ROLLBACK WORK END IF
     #--------------No:MOD-9A0018  end
      RETURN
   END IF
 
   CALL s_yp(l_sfu.sfu02) RETURNING l_yy,l_mm
   IF (l_yy*12+l_mm) > (g_sma.sma51*12+g_sma.sma52) THEN
      LET g_success = 'N'
      CALL cl_err(l_yy,'mfg6090',0) 
     #--------------No:MOD-9A0018  add
      CLOSE t621hcsub_cl
      IF NOT p_inTransaction THEN ROLLBACK WORK END IF
     #--------------No:MOD-9A0018  end
      RETURN
   END IF
 
##No.2987 modify 1998/12/29未過帳之FQC單應不可於此作業作過帳
   IF p_argv<>'3' THEN #FUN-5C0114   #carrier
      SELECT COUNT(DISTINCT sfv17) INTO l_cnt FROM sfv_file,sfu_file
       WHERE sfv01 = l_sfu.sfu01
         AND sfv01 = sfu01
         AND sfv17 IN ( SELECT qcf01 FROM qcf_file
                         WHERE qcf09 = '2' OR qcf14 != 'Y' )
      IF l_cnt > 0 THEN
         CALL cl_err('','asf-711',0)
         LET g_success = 'N'
        #--------------No:MOD-9A0018  add
         CLOSE t621hcsub_cl
         IF NOT p_inTransaction THEN ROLLBACK WORK END IF
        #--------------No:MOD-9A0018  end
         RETURN
      END IF
   END IF
##---------------------------
 
  #--------------------No:MOD-9A0018 mark
  #IF NOT p_inTransaction THEN
  #   BEGIN WORK
  #END IF
 
  #CALL t621hcsub_lock_cl() #FUN-730012
  #OPEN t621hcsub_cl USING l_sfu.sfu01
  #IF STATUS THEN
  #   CALL cl_err("OPEN t621hcsub_cl:", STATUS, 1)
  #   CLOSE t621hcsub_cl
  #   IF NOT p_inTransaction THEN ROLLBACK WORK END IF
  #   LET g_success='N' 
  #   RETURN
  #END IF
  #--------------------No:MOD-9A0018 end
 
   FETCH t621hcsub_cl INTO l_sfu.*          # 鎖住將被更改或取消的資料
   IF SQLCA.sqlcode THEN
      CALL cl_err('lock sfu:',SQLCA.sqlcode,0)     # 資料被他人LOCK
      CLOSE t621hcsub_cl
      IF NOT p_inTransaction THEN ROLLBACK WORK END IF
      LET g_success='N' 
      RETURN
   END IF
 
 
   #LET g_success = 'Y'  #marked by carrier
 
   UPDATE sfu_file SET sfupost='Y'  ,
                       sfu02=l_sfu.sfu02
    WHERE sfu01=l_sfu.sfu01
   IF SQLCA.sqlcode OR SQLCA.sqlerrd[3] = 0 THEN
      LET l_sfu.sfu02 = l_sfu02
      LET g_success='N'
   END IF
   
   #FUN-5C0114...............begin
   IF p_argv='3' THEN
      CALL t621hcsub_upd_sre11("+",l_sfu.sfu01,p_argv)
   ELSE
   #FUN-5C0114...............end
      CALL t621hcsub_s1(l_sfu.sfu01,p_argv)
   END IF

#151204 BY CMP.MaX add---(S)
   UPDATE tc_bar_file SET tc_bartcode ='2' WHERE tc_barserial IN (SELECT tc_bar_tmpserial
                                                                    FROM tc_bar_tmp_file
                                                                   WHERE tc_bar_tmpdj_serno = l_sfu.sfu01)

   IF SQLCA.sqlcode THEN
      LET g_success = 'N'
   END IF
#151204 BY CMP.MaX add---(E)
   #180805 BY CMP.Geoffrey Add (S)
   IF g_user = 'geoffrey' THEN
      CALL t621hc_gen_sfb_csfi301()
   END IF
   #180805 BY CMP.Geoffrey Add (E)
   IF g_success = 'Y' THEN
      LET l_sfu.sfupost='Y'
      IF NOT p_inTransaction THEN COMMIT WORK END IF
      CALL cl_flow_notify(l_sfu.sfu01,'S')
 
#     IF NOT cl_null(g_action_choice) THEN  #FUN-840012
#        #FUN-680139 begin
#         SELECT COUNT(*) INTO l_cnt FROM sfv_file,sfa_file
#          WHERE sfv01 = l_sfu.sfu01
#            AND sfv11 = sfa01 AND sfa11 = 'E'
#         IF l_cnt > 0 THEN 
#           CALL t621hcsub_k() 
#         END IF
#        #FUN-680139 end
#     END IF
   ELSE
      LET l_sfu.sfupost='N'
      IF NOT p_inTransaction THEN ROLLBACK WORK END IF
   END IF
 
END FUNCTION
 
FUNCTION t621hcsub_upd_sre11(p_opt,p_sfu01,p_argv)
   DEFINE p_opt      LIKE type_file.chr1
   DEFINE p_sfu01    LIKE sfu_file.sfu01
   DEFINE p_argv     LIKE type_file.chr1
   DEFINE l_sfu      RECORD LIKE sfu_file.*
   DEFINE l_sfv      RECORD LIKE sfv_file.*
   DEFINE l_srf03    LIKE srf_file.srf03  #機台
   DEFINE l_srf04    LIKE srf_file.srf04  #班別
   DEFINE l_srf05    LIKE srf_file.srf05  #生產/計畫日
   DEFINE l_sw       LIKE type_file.num5
   DEFINE l_ima918   LIKE ima_file.ima918
   DEFINE l_ima921   LIKE ima_file.ima921    
   DEFINE la_tlf  DYNAMIC ARRAY OF RECORD LIKE tlf_file.*   #NO.FUN-8C0131 
   DEFINE l_sql   STRING                                    #NO.FUN-8C0131 
   DEFINE l_i     LIKE type_file.num5                       #NO.FUN-8C0131
 
   IF g_success='N' THEN RETURN END IF
   SELECT * INTO l_sfu.* FROM sfu_file WHERE sfu01 = p_sfu01
   LET l_sw = 1
   IF p_opt = "+" THEN LET l_sw = 1  END IF
   IF p_opt = "-" THEN LET l_sw = -1 END IF
   
   DECLARE t621hcsub_upd_cur CURSOR FOR 
    SELECT sfv_file.*,srf03,srf04,srf05
      FROM sfv_file,srg_file,srf_file
     WHERE sfv01=l_sfu.sfu01
       AND srg01=srf01
       AND sfv17=srg01
       AND sfv14=srg02
 
   FOREACH t621hcsub_upd_cur INTO l_sfv.*,l_srf03,l_srf04,l_srf05
      IF SQLCA.sqlcode THEN
         CALL cl_err('upd sre',SQLCA.sqlcode,1)
         LET g_success='N'
         EXIT FOREACH
      END IF
      IF cl_null(l_sfv.sfv09) THEN LET l_sfv.sfv09 = 0 END IF
      
      UPDATE sre_file set sre11=sre11+l_sfv.sfv09 * l_sw
       WHERE sre03=l_srf03
         AND sre04=l_sfv.sfv11
         AND sre05=l_srf04
         AND sre06=l_srf05
      IF SQLCA.sqlcode THEN
         CALL cl_err('upd sre',SQLCA.sqlcode,1)
         LET g_success='N'
         EXIT FOREACH
      END IF      
 
      #FUN-630105...............begin
      UPDATE srg_file set srg17=srg17+l_sfv.sfv09 * l_sw
       WHERE srg01=l_sfv.sfv17
         AND srg02=l_sfv.sfv14
      #FUN-630105...............end
      IF SQLCA.sqlcode THEN
         CALL cl_err('upd sre',SQLCA.sqlcode,1)
         LET g_success='N'
         EXIT FOREACH
      END IF
 
      #MOD-640120...............begin
      IF (p_opt='-') AND (g_success='Y') THEN
  ##NO.FUN-8C0131   add--begin   
        LET l_sql =  " SELECT  * FROM tlf_file ", 
                     " WHERE tlf01 = '",l_sfv.sfv04,"' ", 
                     "   AND tlf036 = '",l_sfv.sfv01,"' AND tlf037= ",l_sfv.sfv03," "
        DECLARE t621hc_u_tlf_c CURSOR FROM l_sql
        LET l_i = 0 
        CALL la_tlf.clear()
        FOREACH t621hc_u_tlf_c INTO g_tlf.*  
           LET l_i = l_i + 1
           LET la_tlf[l_i].* = g_tlf.*
        END FOREACH     

  ##NO.FUN-8C0131   add--end
         DELETE FROM tlf_file
          WHERE tlf01 =l_sfv.sfv04
            AND (tlf036=l_sfv.sfv01 AND tlf037=l_sfv.sfv03)
         IF SQLCA.sqlcode OR SQLCA.sqlerrd[3]=0 THEN
            CALL cl_err('del tlf',STATUS,0)
            LET g_success = 'N'
            RETURN
         END IF
    ##NO.FUN-8C0131   add--begin
         FOR l_i = 1 TO la_tlf.getlength()
            LET g_tlf.* = la_tlf[l_i].*
            IF NOT s_untlf1('') THEN 
               LET g_success='N' RETURN
            END IF 
         END FOR       
  ##NO.FUN-8C0131   add--end 
         #-----No.FUN-810036-----
         #-----No.MOD-840349-----
         SELECT ima918,ima921 INTO l_ima918,l_ima921
           FROM ima_file
          WHERE ima01 = l_sfv.sfv04
            AND imaacti = "Y"
         
         IF l_ima918 = "Y" OR l_ima921 = "Y" THEN
         #-----No.MOD-840349 END-----
            DELETE FROM tlfs_file
             WHERE tlfs01 = l_sfv.sfv04
               AND tlfs10 = l_sfv.sfv01
               AND tlfs11 = l_sfv.sfv03
           
            IF SQLCA.sqlcode OR SQLCA.sqlerrd[3]=0 THEN
               CALL cl_err('del tlfs',STATUS,0)
               LET g_success = 'N'
               RETURN
            END IF
         END IF   #No.MOD-840349
         #-----No.FUN-810036 END-----
 
      END IF
      #MOD-640120...............end
      IF (g_sma.sma115 = 'Y') AND (g_success='Y') THEN
         IF l_sfv.sfv32 != 0 OR l_sfv.sfv35 != 0 THEN
            CASE p_opt
               WHEN "+"
                  CALL t621hcsub_update_du('s',l_sfu.sfu01,l_sfv.sfv03,p_argv)
               WHEN "-"
                  CALL t621hcsub_update_du('w',l_sfu.sfu01,l_sfv.sfv03,p_argv)
            END CASE
         END IF
      END IF
 
      IF g_success='Y' THEN
         CASE p_opt
            WHEN "+"
               CALL t621hcsub_update_s(l_sfu.sfu01,l_sfv.sfv03,p_argv)
            WHEN "-"
               CALL t621hcsub_update_w(l_sfu.sfu01,l_sfv.sfv03,p_argv)
         END CASE
      END IF
   END FOREACH
 
 
END FUNCTION
#FUN-5C0114...............end
 
FUNCTION t621hcsub_update_du(p_type,p_sfu01,p_sfv03,p_argv)
   DEFINE p_type      LIKE type_file.chr1
   DEFINE p_sfu01     LIKE sfu_file.sfu01
   DEFINE p_sfv03     LIKE sfv_file.sfv03
   DEFINE p_argv      LIKE type_file.chr1
   DEFINE l_sfv       RECORD LIKE sfv_file.*
   DEFINE l_sfu       RECORD LIKE sfu_file.*
   DEFINE l_ima25     LIKE ima_file.ima25
   DEFINE u_type      LIKE type_file.num5
   DEFINE l_ima906    LIKE ima_file.ima906
   DEFINE l_ima907    LIKE ima_file.ima907
 
   IF g_sma.sma115 = 'N' THEN RETURN END IF
 
   IF g_success = 'N' THEN RETURN END IF
   
   IF cl_null(p_sfu01) THEN LET g_success = 'N' RETURN END IF
   IF cl_null(p_sfv03) THEN LET g_success = 'N' RETURN END IF
   
   SELECT * INTO l_sfu.* FROM sfu_file
    WHERE sfu01 = p_sfu01
   IF SQLCA.sqlcode THEN
      CALL cl_err3('sel','sfu_file',p_sfu01,'',SQLCA.sqlcode,'','',1)
      LET g_success = 'N'
      RETURN
   END IF
   
   SELECT * INTO l_sfv.* FROM sfv_file 
    WHERE sfv01 = p_sfu01
      AND sfv03 = p_sfv03
   IF SQLCA.sqlcode THEN
      CALL cl_err3('sel','sfv_file',p_sfu01,p_sfv03,SQLCA.sqlcode,'','',1)
      LET g_success = 'N'
      RETURN
   END IF
 
   IF p_type = 's' THEN
      CASE WHEN p_argv ='1' LET u_type=+1
           WHEN p_argv ='2' LET u_type=-1
           WHEN p_argv ='3' LET u_type=+1 #FUN-5C0114
      END CASE
   ELSE
      CASE WHEN p_argv ='1' LET u_type=-1
           WHEN p_argv ='2' LET u_type=+1
           WHEN p_argv ='3' LET u_type=-1 #FUN-5C0114
      END CASE
   END IF
 
   SELECT ima906,ima907 INTO l_ima906,l_ima907 FROM ima_file
    WHERE ima01 = l_sfv.sfv04
   IF SQLCA.sqlcode THEN
      CALL cl_err3('sel','ima_file',l_sfv.sfv04,'',SQLCA.sqlcode,'','',1)
      LET g_success='N' 
      RETURN
   END IF
   
   SELECT ima25 INTO l_ima25 FROM ima_file
    WHERE ima01=l_sfv.sfv04
   IF SQLCA.sqlcode THEN
      CALL cl_err3('sel','ima_file',l_sfv.sfv04,'',SQLCA.sqlcode,'','',1)
      LET g_success='N' 
      RETURN
   END IF
   IF l_ima906 = '2' THEN  #子母單位
      IF NOT cl_null(l_sfv.sfv33) THEN
         CALL t621hcsub_upd_imgg('1',l_sfv.sfv04,l_sfv.sfv05,l_sfv.sfv06,
                         l_sfv.sfv07,l_sfv.sfv33,l_sfv.sfv34,l_sfv.sfv35,u_type,'2',l_sfu.sfu02)
         IF g_success='N' THEN RETURN END IF
         IF p_type = 's' THEN
            IF NOT cl_null(l_sfv.sfv35) AND l_sfv.sfv35 <> 0 THEN
               CALL t621hcsub_tlff(l_sfv.sfv05,l_sfv.sfv06,l_sfv.sfv07,l_ima25,
                              l_sfv.sfv35,0,l_sfv.sfv33,l_sfv.sfv34,u_type,'2',l_sfu.sfu01,l_sfv.sfv03,p_argv)
               IF g_success='N' THEN RETURN END IF
            END IF
         END IF
      END IF
      IF NOT cl_null(l_sfv.sfv30) THEN
         CALL t621hcsub_upd_imgg('1',l_sfv.sfv04,l_sfv.sfv05,l_sfv.sfv06,
                            l_sfv.sfv07,l_sfv.sfv30,l_sfv.sfv31,l_sfv.sfv32,u_type,'1',l_sfu.sfu02)
         IF g_success='N' THEN RETURN END IF
         IF p_type = 's' THEN
            IF NOT cl_null(l_sfv.sfv32) AND l_sfv.sfv32 <> 0 THEN
               CALL t621hcsub_tlff(l_sfv.sfv05,l_sfv.sfv06,l_sfv.sfv07,l_ima25,
                              l_sfv.sfv32,0,l_sfv.sfv30,l_sfv.sfv31,u_type,'1',l_sfu.sfu01,l_sfv.sfv03,p_argv)
               IF g_success='N' THEN RETURN END IF
            END IF
         END IF
      END IF
      IF p_type = 'w' THEN
         CALL t621hcsub_tlff_w(l_sfu.sfu01,l_sfu.sfu02,l_sfv.sfv03,l_sfv.sfv04)
         IF g_success='N' THEN RETURN END IF
      END IF
   END IF
   IF l_ima906 = '3' THEN  #參考單位
      IF NOT cl_null(l_sfv.sfv33) THEN
         CALL t621hcsub_upd_imgg('2',l_sfv.sfv04,l_sfv.sfv05,l_sfv.sfv06,
                            l_sfv.sfv07,l_sfv.sfv33,l_sfv.sfv34,l_sfv.sfv35,u_type,'2',l_sfu.sfu02)
         IF g_success = 'N' THEN RETURN END IF
         IF p_type = 's' THEN
            IF NOT cl_null(l_sfv.sfv35) AND l_sfv.sfv35 <> 0 THEN
               CALL t621hcsub_tlff(l_sfv.sfv05,l_sfv.sfv06,l_sfv.sfv07,l_ima25,
                              l_sfv.sfv35,0,l_sfv.sfv33,l_sfv.sfv34,u_type,'2',l_sfu.sfu01,l_sfv.sfv03,p_argv)
               IF g_success='N' THEN RETURN END IF
            END IF
         END IF
      END IF  
      IF p_type = 'w' THEN
         CALL t621hcsub_tlff_w(l_sfu.sfu01,l_sfu.sfu02,l_sfv.sfv03,l_sfv.sfv04)
         IF g_success='N' THEN RETURN END IF
      END IF
   END IF
 
END FUNCTION
 
 
FUNCTION t621hcsub_upd_imgg(p_imgg00,p_imgg01,p_imgg02,p_imgg03,p_imgg04,
                       p_imgg09,p_imgg211,p_imgg10,p_type,p_no,p_sfu02)
   DEFINE p_imgg00        LIKE imgg_file.imgg00
   DEFINE p_imgg01        LIKE imgg_file.imgg01
   DEFINE p_imgg02        LIKE imgg_file.imgg02
   DEFINE p_imgg03        LIKE imgg_file.imgg03
   DEFINE p_imgg04        LIKE imgg_file.imgg04
   DEFINE p_imgg09        LIKE imgg_file.imgg09
   DEFINE p_imgg10        LIKE imgg_file.imgg10
   DEFINE p_imgg211       LIKE imgg_file.imgg211
   DEFINE p_no            LIKE type_file.chr1
   DEFINE p_type          LIKE type_file.num10
   DEFINE p_sfu02         LIKE sfu_file.sfu02
   DEFINE l_ima25         LIKE ima_file.ima25
   DEFINE l_ima906        LIKE ima_file.ima906
   DEFINE l_imgg21        LIKE imgg_file.imgg21
   DEFINE l_forupd_sql    STRING
   DEFINE l_cnt           LIKE type_file.num10

    SELECT ima25,ima906 INTO l_ima25,l_ima906
      FROM ima_file WHERE ima01=p_imgg01
    IF SQLCA.sqlcode OR l_ima25 IS NULL THEN
       CALL cl_err('ima25 null',SQLCA.sqlcode,0)
       LET g_success = 'N' RETURN
    END IF
 
    CALL s_umfchk(p_imgg01,p_imgg09,l_ima25) RETURNING l_cnt,l_imgg21

    IF l_cnt = 1 AND NOT (l_ima906='3' AND p_no='2') THEN
       CALL cl_err('','mfg3075',0)
       LET g_success = 'N' RETURN
    END IF
    CALL s_upimgg(p_imgg01,p_imgg02,p_imgg03,p_imgg04,p_imgg09,p_type,p_imgg10,p_sfu02,   #FUN-8C0084
          '','','','','','','','','','',l_imgg21,'','','','','','','',p_imgg211)
    IF g_success='N' THEN RETURN END IF
 
END FUNCTION
 
FUNCTION t621hcsub_tlff(p_ware,p_loca,p_lot,p_unit,p_qty,p_img10,p_uom,p_factor,
                   u_type,p_flag,p_sfu01,p_sfv03,p_argv)
   DEFINE p_ware     LIKE img_file.img02       ##倉庫
   DEFINE p_loca     LIKE img_file.img03       ##儲位
   DEFINE p_lot      LIKE img_file.img04       ##批號
   DEFINE p_unit     LIKE img_file.img09
   DEFINE p_qty      LIKE img_file.img10       ##數量
   DEFINE p_img10    LIKE img_file.img10       ##異動後數量
   DEFINE p_uom      LIKE img_file.img09       ##img 單位
   DEFINE p_factor   LIKE img_file.img21       ##轉換率
   DEFINE u_type     LIKE type_file.num5       ##+1:雜收 -1:雜發  0:報廢
   DEFINE p_sfu01    LIKE sfu_file.sfu01
   DEFINE p_sfv03    LIKE sfv_file.sfv03
   DEFINE p_argv     LIKE type_file.chr1
   DEFINE l_sfu      RECORD LIKE sfu_file.*
   DEFINE l_sfv      RECORD LIKE sfv_file.*
   DEFINE p_flag     LIKE type_file.chr1       
   DEFINE l_imgg10   LIKE imgg_file.imgg10
#  DEFINE l_ima262   LIKE ima_file.ima262
   DEFINE l_avl_stk  LIKE type_file.num15_3    ###GP5.2  #NO.FUN-A20044
   DEFINE l_ima25    LIKE ima_file.ima25
   DEFINE l_ima55    LIKE ima_file.ima55
   DEFINE l_ima86    LIKE ima_file.ima86
   DEFINE g_cnt      LIKE type_file.num5   
   
    IF g_success = 'N' THEN RETURN END IF
    IF cl_null(p_sfu01) OR cl_null(p_sfv03) THEN LET g_success = 'N' END IF
    
    SELECT * INTO l_sfu.* FROM sfu_file
     WHERE sfu01 = p_sfu01
    IF SQLCA.sqlcode THEN
       CALL cl_err3('sel','sfu_file',p_sfu01,'',SQLCA.sqlcode,'','','1')
       LET g_success = 'N'
       RETURN
    END IF
    
    SELECT * INTO l_sfv.* FROM sfv_file
     WHERE sfv01 = p_sfu01
       AND sfv03 = p_sfv03
    IF SQLCA.sqlcode THEN
       CALL cl_err3('sel','sfv_file',p_sfu01,p_sfv03,SQLCA.sqlcode,'','','1')
       LET g_success = 'N'
       RETURN
    END IF    
 
#   CALL s_getima(l_sfv.sfv04) RETURNING l_ima262,l_ima25,l_ima55,l_ima86   #NO.FUN-A20044
    CALL s_getima(l_sfv.sfv04) RETURNING l_avl_stk,l_ima25,l_ima55,l_ima86  #NO.FUN-A20044
 
    IF cl_null(p_ware) THEN LET p_ware=' ' END IF
    IF cl_null(p_loca) THEN LET p_loca=' ' END IF
    IF cl_null(p_lot)  THEN LET p_lot=' '  END IF
    IF cl_null(p_qty)  THEN LET p_qty=0    END IF
 
    IF p_uom IS NULL THEN
       CALL cl_err('p_uom null:','asf-031',1) LET g_success = 'N' RETURN
    END IF
 
    SELECT imgg10 INTO l_imgg10 FROM imgg_file
     WHERE imgg01=l_sfv.sfv04 AND imgg02=p_ware
       AND imgg03=p_loca      AND imgg04=p_lot
       AND imgg09=p_uom
 
    IF cl_null(l_imgg10) THEN LET l_imgg10 = 0 END IF
    INITIALIZE g_tlff.* TO NULL
    LET g_tlff.tlff01=l_sfv.sfv04         #異動料件編號
    IF (p_argv = '1') OR (p_argv = '3') THEN                #完工入庫   #FUN-5C0114 add "OR (g_argv = '3')"
       LET g_tlff.tlff02=60               #資料來源為工單
       LET g_tlff.tlff020=' '
       LET g_tlff.tlff021=' '             #倉庫別
       LET g_tlff.tlff022=' '             #儲位別
       LET g_tlff.tlff023=' '             #批號
    ELSE
       LET g_tlff.tlff02=50               #資料目的為倉庫
       LET g_tlff.tlff020=g_plant
       LET g_tlff.tlff021=p_ware          #倉庫別
       LET g_tlff.tlff022=p_loca          #儲位別
       LET g_tlff.tlff023=p_lot           #入庫批號
    END IF
   #bugno:5393,4839......................................
       LET g_tlff.tlff024=l_imgg10        #異動後庫存數量(同料件主檔之可用量)
       LET g_tlff.tlff025=p_unit          #庫存單位(同料件之庫存單位)
       LET g_tlff.tlff026=l_sfv.sfv11     #單据編號(工單單號)
       LET g_tlff.tlff027=0               #單據項次
   #bugno end............................................
 
    #  Target
    IF (p_argv = '1') OR (p_argv = '3') THEN                #完工入庫   #FUN-5C0114 add "OR (g_argv = '3')"
       LET g_tlff.tlff03=50               #資料目的為倉庫
       LET g_tlff.tlff030=g_plant
       LET g_tlff.tlff031=p_ware          #倉庫別
       LET g_tlff.tlff032=p_loca          #儲位別
       LET g_tlff.tlff033=p_lot           #入庫批號
    ELSE
       LET g_tlff.tlff03=60               #資料來源為工單
       LET g_tlff.tlff030=' '
       LET g_tlff.tlff031=' '             #倉庫別
       LET g_tlff.tlff032=' '             #儲位別
       LET g_tlff.tlff033=' '             #批號
    END IF
   #bugno:5393,4839......................................
       LET g_tlff.tlff034=l_imgg10        #異動後庫存數量(同料件主檔之可用量)
       LET g_tlff.tlff035=p_unit          #生產單位
       LET g_tlff.tlff036=l_sfu.sfu01     #參考號碼
       LET g_tlff.tlff037=l_sfv.sfv03     #項次
   #bugno end............................................
 
    LET g_tlff.tlff04=' '              #工作站
    LET g_tlff.tlff06=l_sfu.sfu02      #入庫日期
    LET g_tlff.tlff07=g_today          #異動資料產生日期
    LET g_tlff.tlff08=TIME             #異動資料產生時:分:秒
    LET g_tlff.tlff09=g_user           #產生人
    LET g_tlff.tlff10=p_qty            #入庫量
    LET g_tlff.tlff11=p_uom            #生產單位
    LET g_tlff.tlff12=p_factor         #發料/庫存轉換率
    #FUN-5C0114...............begin
 
    #IF g_argv = '1' THEN
    #   LET g_tlff.tlff13= 'csft621hc1'
    #ELSE
    #   LET g_tlff.tlff13= 'asft660'
    #END IF
    CASE p_argv
       WHEN "1"
          LET g_tlff.tlff13= 'csft6211hc'
       WHEN "2"
          LET g_tlff.tlff13= 'asft660'
       WHEN "3"
          LET g_tlff.tlff13= 'asrt320'
    END CASE
    #FUN-5C0114...............end
    LET g_tlff.tlff14=''               #原因
    LET g_tlff.tlff15=''               #借方會計科目
    LET g_tlff.tlff16=''               #貸方會計科目
    LET g_tlff.tlff17=' '              #非庫存性料件編號
    CALL s_imaQOH(l_sfv.sfv04)
         RETURNING g_tlff.tlff18       #異動後總庫存量
    LET g_tlff.tlff19= ''              #部門
    LET g_tlff.tlff20= l_sfu.sfu06     #project no.
    LET g_tlff.tlff21= ''
    LET g_tlff.tlff61= ''
    LET g_tlff.tlff62= l_sfv.sfv11     #單据編號(工單單號)
    LET g_tlff.tlff63= ''
    LET g_tlff.tlff64= ''
    LET g_tlff.tlff65= ''
    LET g_tlff.tlff66= ''
    LET g_tlff.tlff930=l_sfv.sfv930  #FUN-670103
    IF cl_null(l_sfv.sfv35) OR l_sfv.sfv35=0 THEN
       CALL s_tlff(p_flag,NULL)
    ELSE
       CALL s_tlff(p_flag,l_sfv.sfv33)
    END IF
END FUNCTION
 
FUNCTION t621hcsub_tlff_w(p_sfu01,p_sfu02,p_sfv03,p_sfv04)
   DEFINE p_sfu01       LIKE sfu_file.sfu01
   DEFINE p_sfu02       LIKE sfu_file.sfu02
   DEFINE p_sfv03       LIKE sfv_file.sfv03
   DEFINE p_sfv04       LIKE sfv_file.sfv04
 
    CALL cl_msg("d_tlff!")
    CALL ui.Interface.refresh()
 
    DELETE FROM tlff_file
     WHERE tlff01 =p_sfv04
       AND ((tlff026=p_sfu01 AND tlff027=p_sfv03) OR
            (tlff036=p_sfu01 AND tlff037=p_sfv03)) #異動單號/項次
       AND tlff06 =p_sfu02 #異動日期
 
    IF STATUS THEN
       CALL cl_err('del tlff:',STATUS,1) LET g_success='N' RETURN
    END IF
END FUNCTION
 
#FUN-540055  --end
 
FUNCTION t621hcsub_update_s(p_sfu01,p_sfv03,p_argv)
  DEFINE p_sfu01       LIKE sfu_file.sfu01
  DEFINE p_sfv03       LIKE sfv_file.sfv03
  DEFINE p_argv        LIKE type_file.chr1
  DEFINE p_ware        LIKE img_file.img02
  DEFINE p_loca        LIKE img_file.img03
  DEFINE p_lot         LIKE img_file.img04
  DEFINE p_qty         LIKE img_file.img10        ##數量
  DEFINE p_uom         LIKE img_file.img09        ##img 單位
  DEFINE p_factor      LIKE ima_file.ima31_fac    ##轉換率
  DEFINE l_qty         LIKE img_file.img10        ##異動後數量
  DEFINE l_ima01       LIKE ima_file.ima01
  DEFINE l_ima25       LIKE ima_file.ima25
  DEFINE l_ima55       LIKE ima_file.ima55
# DEFINE l_imaqty      LIKE ima_file.ima262
  DEFINE l_imaqty      LIKE type_file.num15_3     ###GP5.2  #NO.FUN-A20044
  DEFINE l_imafac      LIKE img_file.img21
  DEFINE u_type        LIKE type_file.num5        ##+1:入庫 -1:入庫退回
  DEFINE l_img         RECORD
                       img10   LIKE img_file.img10,
                       img16   LIKE img_file.img16,
                       img23   LIKE img_file.img23,
                       img24   LIKE img_file.img24,
                       img09   LIKE img_file.img09,
                       img21   LIKE img_file.img21
                       END RECORD
  DEFINE l_img09       LIKE img_file.img09  
  DEFINE l_sfu         RECORD LIKE sfu_file.*
  DEFINE l_sfv         RECORD LIKE sfv_file.*
  DEFINE l_i           LIKE type_file.num5  
  DEFINE l_ima86       LIKE ima_file.ima86
  DEFINE l_cnt         LIKE type_file.num10
  DEFINE l_sql         STRING
  DEFINE l_msg         STRING                     #FUN-980043      

    IF g_success = 'N' THEN RETURN END IF
    IF cl_null(p_sfu01) OR cl_null(p_sfv03) THEN LET g_success = 'N' END IF
    
    SELECT * INTO l_sfu.* FROM sfu_file
     WHERE sfu01 = p_sfu01
    IF SQLCA.sqlcode THEN
       CALL cl_err3('sel','sfu_file',p_sfu01,'',SQLCA.sqlcode,'','','1')
       LET g_success = 'N'
       RETURN
    END IF
    
    SELECT * INTO l_sfv.* FROM sfv_file
     WHERE sfv01 = p_sfu01
       AND sfv03 = p_sfv03
    IF SQLCA.sqlcode THEN
       CALL cl_err3('sel','sfv_file',p_sfu01,p_sfv03,SQLCA.sqlcode,'','','1')
       LET g_success = 'N'
       RETURN
    END IF 
    
    LET p_ware = l_sfv.sfv05
    LET p_loca = l_sfv.sfv06
    LET p_lot  = l_sfv.sfv07
    LET p_qty  = l_sfv.sfv09
    LET p_uom  = l_sfv.sfv08
     
    IF cl_null(p_ware) THEN LET p_ware=' ' END IF
    IF cl_null(p_loca) THEN LET p_loca=' ' END IF
    IF cl_null(p_lot)  THEN LET p_lot=' '  END IF
    IF cl_null(p_qty)  THEN LET p_qty=0    END IF
                                   #生產單位
    #No:9697
    IF cl_null(l_sfv.sfv06) THEN LET l_sfv.sfv06=' ' END IF
    IF cl_null(l_sfv.sfv07) THEN LET l_sfv.sfv07=' ' END IF
    #No:9697
 
## No:2572 modify 1998/10/20 ----------------------------------
    SELECT img09 INTO l_img09 FROM img_file
     WHERE img01=l_sfv.sfv04 AND img02=l_sfv.sfv05
       AND img03=l_sfv.sfv06 AND img04=l_sfv.sfv07
    IF STATUS THEN
       CALL cl_err('sel img09',status,1) LET g_success = 'N' RETURN
    END IF
## --------------------------------------------------------------
 
    CALL s_umfchk(l_sfv.sfv04,p_uom,l_img09) RETURNING l_i,p_factor
    IF l_i = 1 THEN
        ###Modify:98/11/15 ----庫存/料號單位無法轉換 ------####
        #CALL cl_err('庫存/料號單位無法轉換',STATUS,1)
       #CALL cl_err('sfv08/img09: ','abm-731',1) #FUN-980043                                                                       
        LET l_msg=p_sfv03,'',l_sfv.sfv04,'','sfv08/img09: ' #FUN-980043                                                                    
        CALL cl_err(l_msg,'abm-731',1)       #FUN-980043  
        LET g_success ='N'
    END IF
    IF p_uom IS NULL THEN
       CALL cl_err('p_uom null:','asf-031',1) LET g_success = 'N' RETURN
    END IF

    # update img_file
    CALL cl_msg("update img_file ...")
 
     LET g_forupd_sql = "SELECT img10,img16,img23,img24,img09,img21 ",  #091021 mark
                       "FROM img_file",
                       " WHERE img01= ? AND img02= ? AND img03= ? AND img04= ? ",
                       " FOR UPDATE"
    LET g_forupd_sql = cl_forupd_sql(g_forupd_sql)
    DECLARE img_lock CURSOR FROM g_forupd_sql
 
    OPEN img_lock USING l_sfv.sfv04,p_ware,p_loca, p_lot
    IF STATUS THEN
       CALL cl_err('lock img fail',STATUS,1) LET g_success='N' RETURN
    END IF
 
    FETCH img_lock INTO l_img.*
    IF STATUS THEN
       CALL cl_err('lock img fail',STATUS,1) LET g_success='N' RETURN
    END IF
 
    IF cl_null(l_img.img10) THEN LET l_img.img10=0 END IF
 
    IF p_argv = '2' THEN    #退回
       LET l_qty= l_img.img10 - p_qty
       IF l_qty < 0 THEN  #庫存不足, Fail
          IF NOT cl_confirm('mfg3469') THEN  LET g_success='N' RETURN END IF
       END IF
    END IF
 
    CASE WHEN p_argv = '1' LET u_type = +1
         WHEN p_argv = '2' LET u_type = -1
         WHEN p_argv = '3' LET u_type = +1 #FUN-5C0114
    END CASE
 
    #FUN-550011................begin
    IF u_type = -1 THEN
       IF NOT s_stkminus(l_sfv.sfv04,l_sfv.sfv05,l_sfv.sfv06,l_sfv.sfv07,
                         l_sfv.sfv09,p_factor,l_sfu.sfu02,g_sma.sma894[3,3]) THEN
          LET g_success='N'
          RETURN
       END IF
    END IF
 
    CALL s_upimg(l_sfv.sfv04,p_ware,p_loca,p_lot,u_type,p_qty*p_factor,g_today,  #FUN-8C0084
                 '','','','',l_sfv.sfv01,l_sfv.sfv03,   #No.MOD-860261
                 '','','','','','','','','','','','')
    IF g_success='N' THEN RETURN END IF

    #update ima_file
    CALL cl_msg("update ima_file ...")
 
    LET g_forupd_sql= "SELECT ima25,ima86 FROM ima_file WHERE ima01= ? FOR UPDATE"
    LET g_forupd_sql = cl_forupd_sql(g_forupd_sql)
    DECLARE ima_lock CURSOR FROM g_forupd_sql
 
    OPEN ima_lock USING l_sfv.sfv04
    IF STATUS THEN
       CALL cl_err('lock ima fail',STATUS,1) LET g_success='N' RETURN
    END IF
 
    FETCH ima_lock INTO l_ima25,l_ima86
    IF STATUS THEN
       CALL cl_err('lock ima fail',STATUS,1) LET g_success='N' RETURN
    END IF
    IF l_sfv.sfv08=l_ima25 THEN
       LET l_imafac = 1
    ELSE
       CALL s_umfchk(l_sfv.sfv04,l_sfv.sfv08,l_ima25)
                RETURNING l_cnt,l_imafac
    END IF
    IF cl_null(l_imafac)  THEN
       ####Modify:98/11/15 ----庫存/料號無法轉換 -------###
       #CALL cl_err('庫存/料號單位無法轉換',STATUS,1)
      #CALL cl_err('sfv08/ima25: ','abm-731',1) #FUN-980043                                                                      
       LET l_msg=p_sfv03,'',l_sfv.sfv04,'','sfv08/img25: ' #FUN-980043                                                                      
       CALL cl_err(l_msg,'abm-731',1)       #FUN-980043       
       LET g_success ='N'
       ####LET l_imafac = 1
    END IF
    LET l_imaqty = p_qty * l_imafac
    CALL s_udima(l_sfv.sfv04,l_img.img23,l_img.img24,l_imaqty,
                    l_sfu.sfu02,u_type)  RETURNING l_cnt #MOD-A90120 mod g_today->l_sfu.sfu02
    IF g_success='N' THEN RETURN END IF
    #sfv
#------------------------------------------- insert tlf_file
    CALL cl_msg("insert tlf_file ...")
    IF g_success='Y' THEN
       CALL t621hcsub_tlf(p_factor,l_sfu.sfu01,l_sfv.sfv03,p_argv)
    END IF
    LET l_sql="seq#",l_sfv.sfv03 USING'<<<',' post ok!'
    CALL cl_msg(l_sql)
END FUNCTION
 
 
FUNCTION t621hcsub_tlf(p_factor,p_sfu01,p_sfv03,p_argv)
  DEFINE p_sfu01       LIKE sfu_file.sfu01
  DEFINE p_sfv03       LIKE sfv_file.sfv03
  DEFINE p_argv        LIKE type_file.chr1
  DEFINE l_sfu         RECORD LIKE sfu_file.*
  DEFINE l_sfv         RECORD LIKE sfv_file.*
# DEFINE l_ima262      LIKE ima_file.ima262
  DEFINE l_avl_stk     LIKE type_file.num15_3    ###GP5.2  #NO.FUN-A20044
  DEFINE l_ima25       LIKE ima_file.ima25
  DEFINE l_ima55       LIKE ima_file.ima55
  DEFINE l_ima86       LIKE ima_file.ima86
  DEFINE p_factor      LIKE ima_file.ima31_fac ##轉換率
  DEFINE p_img10       LIKE img_file.img10     #異動後數量
  DEFINE l_img09       LIKE img_file.img09     #No: MOD-570344 add
  DEFINE l_sfb97       LIKE sfb_file.sfb97
 
    IF g_success = 'N' THEN RETURN END IF
    IF cl_null(p_sfu01) OR cl_null(p_sfv03) THEN LET g_success = 'N' END IF
    
    SELECT * INTO l_sfu.* FROM sfu_file
     WHERE sfu01 = p_sfu01
    IF SQLCA.sqlcode THEN
       CALL cl_err3('sel','sfu_file',p_sfu01,'',SQLCA.sqlcode,'','','1')
       LET g_success = 'N'
       RETURN
    END IF
    
    SELECT * INTO l_sfv.* FROM sfv_file
     WHERE sfv01 = p_sfu01
       AND sfv03 = p_sfv03
    IF SQLCA.sqlcode THEN
       CALL cl_err3('sel','sfv_file',p_sfu01,p_sfv03,SQLCA.sqlcode,'','','1')
       LET g_success = 'N'
       RETURN
    END IF 
 
    INITIALIZE g_tlf.* TO NULL
 
#   CALL s_getima(l_sfv.sfv04) RETURNING l_ima262,l_ima25,l_ima55,l_ima86   #NO.FUN-A20044
    CALL s_getima(l_sfv.sfv04) RETURNING l_avl_stk,l_ima25,l_ima55,l_ima86  #NO.FUN-A20044
   #--No.MOD-570344
    SELECT img09,img10 INTO l_img09,p_img10 FROM img_file
         WHERE img01 = l_sfv.sfv04 AND img02 = l_sfv.sfv05
           AND img03 = l_sfv.sfv06 AND img04 = l_sfv.sfv07
   #--No.MOD-570344 end
  #----------------No.MOD-930013 add
   LET l_sfb97 = NULL
   SELECT sfb97 INTO l_sfb97 FROM sfb_file WHERE sfb01=l_sfv.sfv11
  #----------------No.MOD-930013 end
 
    #  Source
    LET g_tlf.tlf01=l_sfv.sfv04      #異動料件編號
    IF (p_argv = '1') OR (p_argv = '3') THEN                #完工入庫  #FUN-5C0114 add "OR (g_argv = '3')"
       LET g_tlf.tlf02=60               #資料來源為工單
       LET g_tlf.tlf020=' '
       LET g_tlf.tlf021=' '             #倉庫別
       LET g_tlf.tlf022=' '             #儲位別
       LET g_tlf.tlf023=' '             #批號
    ELSE
       LET g_tlf.tlf02=50               #資料目的為倉庫
       LET g_tlf.tlf020=g_plant
       LET g_tlf.tlf021=l_sfv.sfv05     #倉庫別
       LET g_tlf.tlf022=l_sfv.sfv06     #儲位別
       LET g_tlf.tlf023=l_sfv.sfv07     #入庫批號
    END IF
   #bugno:5393,4839......................................
        #---No.MOD-570344 modify
       #LET g_tlf.tlf024=l_ima262        #異動後庫存數量(同料件主檔之可用量)
       #LET g_tlf.tlf025=l_ima25         #庫存單位(同料件之庫存單位)
       LET g_tlf.tlf024=p_img10
       LET g_tlf.tlf025=l_img09
       #--No.MOD-570344 end
       LET g_tlf.tlf026=l_sfu.sfu01     #單据編號(工單單號)
       LET g_tlf.tlf027=l_sfv.sfv03     #單據項次
   #bugno end............................................
 
    #  Target
    IF (p_argv = '1') OR (p_argv = '3') THEN                #完工入庫  #FUN-5C0114 add "OR (g_argv = '3')"
       LET g_tlf.tlf03=50               #資料目的為倉庫
       LET g_tlf.tlf030=g_plant
       LET g_tlf.tlf031=l_sfv.sfv05     #倉庫別
       LET g_tlf.tlf032=l_sfv.sfv06     #儲位別
       LET g_tlf.tlf033=l_sfv.sfv07     #入庫批號
    ELSE
       LET g_tlf.tlf03=60               #資料來源為工單
       LET g_tlf.tlf030=' '
       LET g_tlf.tlf031=' '             #倉庫別
       LET g_tlf.tlf032=' '             #儲位別
       LET g_tlf.tlf033=' '             #批號
    END IF
   #bugno:5393,4839......................................
        #---No.MOD-570344 modify
       #LET g_tlf.tlf034=l_ima262        #異動後庫存數量(同料件主檔之可用量)
       #LET g_tlf.tlf035=l_ima25         #庫存單位(同料件之庫存單位)
       LET g_tlf.tlf034=p_img10
       LET g_tlf.tlf035=l_img09
       #--No.MOD-570344 end
       LET g_tlf.tlf036=l_sfu.sfu01     #參考號碼
       LET g_tlf.tlf037=l_sfv.sfv03     #項次
   #bugno end............................................
 
    LET g_tlf.tlf04=' '              #工作站
    LET g_tlf.tlf06=l_sfu.sfu02      #入庫日期
    LET g_tlf.tlf07=g_today          #異動資料產生日期
    LET g_tlf.tlf08=TIME             #異動資料產生時:分:秒
    LET g_tlf.tlf09=g_user           #產生人
    LET g_tlf.tlf10=l_sfv.sfv09      #入庫量
    LET g_tlf.tlf11=l_sfv.sfv08      #生產單位
    LET g_tlf.tlf12=p_factor         #發料/庫存轉換率
    #FUN-5C0114...............begin
 
    #IF g_argv = '1' THEN
    #   LET g_tlf.tlf13= 'csft621hc1'
    #ELSE
    #   LET g_tlf.tlf13= 'asft660'
    #END IF
    CASE p_argv
       WHEN "1"
          LET g_tlf.tlf13= 'csft6211hc'
       WHEN "2"
          LET g_tlf.tlf13= 'asft660'
       WHEN "3"
          LET g_tlf.tlf13= 'asrt320'
    END CASE
    #FUN-5C0114...............end
    LET g_tlf.tlf14=''               #原因
    LET g_tlf.tlf15=''               #借方會計科目
    LET g_tlf.tlf16=''               #貸方會計科目
    LET g_tlf.tlf17=' '              #非庫存性料件編號
    CALL s_imaQOH(l_sfv.sfv04)
         RETURNING g_tlf.tlf18       #異動後總庫存量
   #start FUN-5B0077
   #LET g_tlf.tlf19= ''              #部門
    SELECT ccz06 INTO g_ccz.ccz06 FROM ccz_file
    IF g_ccz.ccz06 ='2' THEN
       LET g_tlf.tlf19= l_sfu.sfu04  #部門
    END IF
   #end FUN-5B0077
    #LET g_tlf.tlf20= l_sfu.sfu06     #project no.  #FUN-810045
    LET g_tlf.tlf21= ''
    LET g_tlf.tlf61= ''
    LET g_tlf.tlf62= l_sfv.sfv11     #單据編號(工單單號)
    LET g_tlf.tlf63= ''
    LET g_tlf.tlf64= l_sfb97         #No.MOD-930013 modify
    LET g_tlf.tlf65= ''
    LET g_tlf.tlf66= ''
    LET g_tlf.tlf930=l_sfv.sfv930  #FUN-670103
 
   #FUN-810045 add begin
    LET g_tlf.tlf20 = l_sfv.sfv41
    LET g_tlf.tlf41 = l_sfv.sfv42
    LET g_tlf.tlf42 = l_sfv.sfv43
    LET g_tlf.tlf43 = l_sfv.sfv44
   #FUN-810045 add end
 
    CALL s_tlf(1,0)                  #1:需取得標準成本 0:不需詢問原因
END FUNCTION
 
FUNCTION t621hcsub_update_w(p_sfu01,p_sfv03,p_argv)
  DEFINE p_sfu01       LIKE sfu_file.sfu01
  DEFINE p_sfv03       LIKE sfv_file.sfv03
  DEFINE p_argv        LIKE type_file.chr1  
  DEFINE p_ware        LIKE img_file.img02
  DEFINE p_loca        LIKE img_file.img03
  DEFINE p_lot         LIKE img_file.img04
  DEFINE p_qty         LIKE img_file.img10        ##數量
  DEFINE p_uom         LIKE img_file.img09        ##img 單
  DEFINE u_type        LIKE type_file.num5        ##-1:入庫 +1:入庫退回
  DEFINE p_factor      LIKE ima_file.ima31_fac    ##轉換率
  DEFINE l_qty         LIKE img_file.img10        ##異動後數量
  DEFINE l_ima01       LIKE ima_file.ima01
  DEFINE l_ima25       LIKE ima_file.ima25
  DEFINE l_ima55       LIKE ima_file.ima55
# DEFINE l_imaqty      LIKE ima_file.ima262
  DEFINE l_imaqty      LIKE type_file.num15_3     ###GP5.2  #NO.FUN-A20044
  DEFINE l_imafac      LIKE img_file.img21
  DEFINE l_img         RECORD
                       img10   LIKE img_file.img10,
                       img16   LIKE img_file.img16,
                       img23   LIKE img_file.img23,
                       img24   LIKE img_file.img24,
                       img09   LIKE img_file.img09,
                       img21   LIKE img_file.img21
                       END RECORD
  DEFINE l_img09       LIKE img_file.img09  
  DEFINE l_sfu         RECORD LIKE sfu_file.*
  DEFINE l_sfv         RECORD LIKE sfv_file.*
  DEFINE l_i           LIKE type_file.num5  
  DEFINE l_ima86       LIKE ima_file.ima86
  DEFINE l_cnt         LIKE type_file.num10
  DEFINE l_forupd_sql  STRING
  DEFINE l_msg         STRING                       #FUN-980043        
    IF g_success = 'N' THEN RETURN END IF
    IF cl_null(p_sfu01) OR cl_null(p_sfv03) THEN LET g_success = 'N' END IF
    
    SELECT * INTO l_sfu.* FROM sfu_file
     WHERE sfu01 = p_sfu01
    IF SQLCA.sqlcode THEN
       CALL cl_err3('sel','sfu_file',p_sfu01,'',SQLCA.sqlcode,'','','1')
       LET g_success = 'N'
       RETURN
    END IF
    
    SELECT * INTO l_sfv.* FROM sfv_file
     WHERE sfv01 = p_sfu01
       AND sfv03 = p_sfv03
    IF SQLCA.sqlcode THEN
       CALL cl_err3('sel','sfv_file',p_sfu01,p_sfv03,SQLCA.sqlcode,'','','1')
       LET g_success = 'N'
       RETURN
    END IF 
    
    LET p_ware = l_sfv.sfv05
    LET p_loca = l_sfv.sfv06
    LET p_lot  = l_sfv.sfv07
    LET p_qty  = l_sfv.sfv09
    LET p_uom  = l_sfv.sfv08
 
    IF cl_null(p_ware) THEN LET p_ware=' ' END IF
    IF cl_null(p_loca) THEN LET p_loca=' ' END IF
    IF cl_null(p_lot)  THEN LET p_lot=' ' END IF
    IF cl_null(p_qty)  THEN LET p_qty=0 END IF
 
    SELECT img09 INTO l_img09 FROM img_file
     WHERE img01=l_sfv.sfv04 AND img02=l_sfv.sfv05
       AND img03=l_sfv.sfv06 AND img04=l_sfv.sfv07
    IF STATUS THEN
       CALL cl_err('sel img09',status,1)
       LET g_success = 'N'
       RETURN
    END IF
 
    CALL s_umfchk(l_sfv.sfv04,p_uom,l_img09) RETURNING l_i,p_factor
    IF l_i = 1 THEN
        ####Modify:98/11/15 ----庫存/料號單位無法轉換-----###
        #CALL cl_err('庫存/料號單位無法轉換',STATUS,1)
       #CALL cl_err('sfv08/img09: ','abm-731',1) #FUN-980043                                                                     
        LET l_msg=p_sfv03,'',l_sfv.sfv04,'','sfv08/img09: ' #FUN-980043                                                                     
        CALL cl_err(l_msg,'abm-731',1)       #FUN-980043 
        LET g_success ='N'
    END IF
 
    IF p_uom IS NULL THEN
       CALL cl_err('p_uom null:','asf-031',1)
       LET g_success = 'N'
       RETURN
    END IF
 
    CALL cl_msg("update img_file ...")
 
    LET g_forupd_sql = "SELECT img10,img16,img23,img24,img09,img21",  #091021 
                       " FROM img_file ",
                       " WHERE img01= ? AND img02 = ? AND img03= ? AND img04= ?",
                       " FOR UPDATE"
    LET g_forupd_sql = cl_forupd_sql(g_forupd_sql)
    DECLARE img_lock_w CURSOR FROM g_forupd_sql
 
    OPEN img_lock_w USING l_sfv.sfv04,p_ware,p_loca,p_lot
    IF STATUS THEN
       CALL cl_err('lock img fail',STATUS,1) LET g_success='N' RETURN
    END IF
 
    FETCH img_lock_w INTO l_img.*
    IF STATUS THEN
       CALL cl_err('lock img fail',STATUS,1) LET g_success='N' RETURN
    END IF
 
    IF cl_null(l_img.img10) THEN LET l_img.img10=0 END IF
    CASE WHEN p_argv = '1' LET u_type = -1
         WHEN p_argv = '2' LET u_type = +1
         WHEN p_argv = '3' LET u_type = -1 #FUN-5C0114
    END CASE
    CALL s_upimg(l_sfv.sfv04,p_ware,p_loca,p_lot,u_type,p_qty*p_factor,g_today,  #FUN-8C0084
                 '','','','',l_sfv.sfv01,l_sfv.sfv03,   #No.MOD-860261
                 '','','','','','','','','','','','')
    IF g_success='N' THEN RETURN END IF
 
    #update ima_file
    CALL cl_msg("update ima_file ...")
 
    LET g_forupd_sql = "SELECT ima25,ima86 FROM ima_file ",
                       " WHERE ima01= ?  FOR UPDATE"
    LET g_forupd_sql = cl_forupd_sql(g_forupd_sql)
    DECLARE ima_lock_w CURSOR FROM g_forupd_sql
 
    OPEN ima_lock_w USING l_sfv.sfv04
    IF STATUS THEN
       CALL cl_err('lock ima fail',STATUS,1) LET g_success='N' RETURN
    END IF
 
    FETCH ima_lock_w INTO l_ima25,l_ima86
    IF STATUS THEN
       CALL cl_err('lock ima fail',STATUS,1) LET g_success='N' RETURN
    END IF
 
    IF l_sfv.sfv08=l_ima25 THEN
       LET l_imafac = 1
    ELSE
       CALL s_umfchk(l_sfv.sfv04,l_sfv.sfv08,l_ima25)
                RETURNING l_cnt,l_imafac
    END IF
    IF cl_null(l_imafac)  THEN
       ###Modify:98/11/15 -----單位無法轉換 -----####
      #CALL cl_err('','abm-731',1) #FUN-980043                                                                                      
       LET l_msg=p_sfv03,'',l_sfv.sfv04,'' #FUN-980043                                                                                      
       CALL cl_err(l_msg,'abm-731',1)       #FUN-980043    
       LET g_success ='N'
       ####LET l_imafac = 1
    END IF
 
    LET l_imaqty = p_qty * l_imafac
    CALL s_udima(l_sfv.sfv04,l_img.img23,l_img.img24,l_imaqty,l_sfu.sfu02,u_type) #MOD-A90120 mod g_today->l_sfu.sfu02
         RETURNING l_cnt
    IF g_success='N' THEN RETURN END IF
 
END FUNCTION
 
FUNCTION t621hcsub_s1(p_sfu01,p_argv)
  DEFINE p_sfu01    LIKE sfu_file.sfu01
  DEFINE p_argv     LIKE type_file.chr1
  DEFINE l_sfu      RECORD LIKE sfu_file.*
  DEFINE l_sfv      RECORD LIKE sfv_file.*
  DEFINE l_sfb      RECORD LIKE sfb_file.*
  DEFINE l_sfv091   LIKE sfv_file.sfv09,
         l_sfv092   LIKE sfv_file.sfv09,
         l_sfv09    LIKE sfv_file.sfv09,
         l_qcf091   LIKE qcf_file.qcf091,
         l_str      LIKE type_file.chr20,         #No.FUN-680121 SMALLINT #No.MOD-5B0054 add
         l_cnt      LIKE type_file.num5,          #No.MOD-5B0054 add        #No.FUN-680121 SMALLINT
         s_sfv09    LIKE sfv_file.sfv09
  DEFINE l_flag     LIKE type_file.num5                 #FUN-810038
  DEFINE l_ima153   LIKE ima_file.ima153   #FUN-910053 
  DEFINE l_min_set  LIKE sfb_file.sfb08
  DEFINE l_ecm311   LIKE ecm_file.ecm311
  DEFINE l_ecm315   LIKE ecm_file.ecm315
  DEFINE l_ecm_out  LIKE ecm_file.ecm311
  DEFINE l_date     LIKE sfu_file.sfu02    #No:MOD-940257 add
  DEFINE l_sfb39    LIKE sfb_file.sfb39    #No:MOD-940257 add
  DEFINE l_ecm012   LIKE ecm_file.ecm012  #FUN-A50066
  DEFINE l_ecm03    LIKE ecm_file.ecm03   #FUN-A50066 
  DEFINE l_percent  LIKE ima_file.ima31_fac          #161021 BY CMP.MaX add
  DEFINE l_min_set_t  LIKE sfb_file.sfb08            #161021 BY CMP.MaX add
  DEFINE l_sfb_qty    LIKE sfb_file.sfb081  #161206 BY CMP.MaX add
  DEFINE l_sfb_qty_t  LIKE sfb_file.sfb081  #161206 BY CMP.MaX add
  DEFINE l_sfb09    LIKE sfb_file.sfb081  #161206 BY CMP.MaX add
  DEFINE l_sfb12    LIKE sfb_file.sfb081  #161206 BY CMP.MaX add
  
  CALL s_showmsg_init()   #No.FUN-6C0083 
  
  IF g_success='N' THEN RETURN END IF
  SELECT * INTO l_sfu.* FROM sfu_file WHERE sfu01 = p_sfu01
   
  DECLARE t621hcsub_s1_c CURSOR FOR
   SELECT * FROM sfv_file WHERE sfv01=l_sfu.sfu01
 
  FOREACH t621hcsub_s1_c INTO l_sfv.*
     IF cl_null(l_sfv.sfv04) THEN
        LET g_success='N'
        CONTINUE FOREACH
     END IF
    #----------------No:MOD-940257 add
     SELECT sfb39 INTO l_sfb39 FROM sfb_file WHERE sfb01=l_sfv.sfv11
     IF l_sfb39 != '2' THEN
        #檢查工單最小發料日是否小於入庫日
        SELECT MIN(sfp03) INTO l_date FROM sfe_file,sfp_file  
         WHERE sfe01 = l_sfv.sfv11 AND sfe02 = sfp01
        IF STATUS OR cl_null(l_date) THEN
           SELECT MIN(sfp03) INTO l_date FROM sfs_file,sfp_file
            WHERE sfs03=l_sfv.sfv11 AND sfp01=sfs01
        END IF
      
        IF cl_null(l_date) OR l_date > l_sfu.sfu02 THEN
           LET g_success='N'   
           CALL cl_err(l_sfv.sfv11,'asf-824',1)
           EXIT FOREACH
        END IF
     END IF
    #----------------No:MOD-940257 end
      
     IF l_sfv.sfv16= 'N' THEN   #TQC-630246
#-------No.MOD-5B0054 begin
        LET l_cnt = 0
        SELECT COUNT(*) INTO l_cnt FROM sfb_file
         WHERE sfb01=l_sfv.sfv11 AND sfb05=l_sfv.sfv04
        IF l_cnt <= 0 THEN
           LET l_str ="Line No:",l_sfv.sfv03 USING "<<<<<"
           CALL cl_err(l_str,'asf-968',1)
           LET g_success='N'
           CONTINUE FOREACH
        END IF
#------No.MOD-5B0054 end
     END IF   #TQC-630246 
 
     #---->聯產品
     #認定聯產品的時機點為:2.完工入庫
     IF g_sma.sma105 = '2' THEN
        SELECT COUNT(*) INTO l_cnt
          FROM bmm_file,sfb_file
         WHERE sfb01 = l_sfv.sfv11  #工單編號   #No:7813 modify
           AND bmm01 = sfb05        #主件編號
           AND bmm03 = l_sfv.sfv04  #聯產品料號
           AND bmm05 = 'N'          #無效
        IF l_cnt >= 1 THEN
           #存在無效的聯產品料號,請檢查此完工入庫單資料正確否
           CALL cl_err(l_sfv.sfv04,'aqc-424',1)
           LET g_success = 'N'
           RETURN
        END IF
     END IF
 
     IF l_sfv.sfv09 = 0 THEN
        CALL cl_err(l_sfv.sfv09,'asf-660',1)
        LET g_success = 'N'
        EXIT FOREACH
     END IF
 
     SELECT * INTO l_sfb.* FROM sfb_file WHERE sfb01=l_sfv.sfv11
 
#----No.B363
     IF l_sfb.sfb04='8' THEN
        CALL cl_err(l_sfb.sfb01,'mfg3430',1)
        LET g_success='N'
        EXIT FOREACH
     END IF
#----No.B363 END
 
#----入庫量不可大於FQC量
     IF p_argv = '1' THEN   #入庫
        LET l_sfv09=0     #已 key 之入庫量(不分是否已過帳)
       #應抓取該張工單在別張完工入庫量已過帳的數量並加上此張要過帳的數量後再與最小套數相比
        SELECT SUM(sfv09) INTO l_sfv09 FROM sfv_file,sfu_file
         WHERE sfv11 = l_sfv.sfv11
           AND sfv01 = sfu01
           AND sfu00 = '1'           #完工入庫
           AND sfuconf <> 'X' #FUN-660137
           AND sfupost = 'Y'          #MOD-AB0148 add
          #AND sfu01 != g_sfu.sfu01   #MOD-AB0148 add #MOD-BA0161
           AND sfu01 != l_sfv.sfv01   #MOD-BA0161
         # AND sfu01 != g_sfu.sfu01   #No.B218 010508 mark
        IF l_sfv09 IS NULL THEN LET l_sfv09 =0 END IF
        LET l_sfv09 = l_sfv09 + l_sfv.sfv09     #MOD-AB0148 add
 
        LET l_min_set=0
        IF l_sfb.sfb39 != '2' THEN
           CALL s_get_ima153(l_sfv.sfv04) RETURNING l_ima153  #FUN-910053  
           #工單完工方式為'2' pull 不check min_set
           #CALL s_minp(l_sfv.sfv11,g_sma.sma73,g_sma.sma74,'') #FUN-910053
           # CALL s_minp(l_sfv.sfv11,g_sma.sma73,l_ima153,'')    #FUN-910053
           CALL s_minp(l_sfv.sfv11,g_sma.sma73,l_ima153,'','','')    #FUN-A60027
                        RETURNING l_cnt,l_min_set
            IF l_cnt !=0  THEN
               CALL cl_err(l_sfv.sfv09,'asf-549',1)
               LET g_success = 'N'
               CONTINUE FOREACH
            END IF
 
 #W/O 總入庫量大於最小套數 --
            IF l_sfb.sfb93='N' THEN
#161206 BY CMP.MaX add---(S)
               SELECT sfb081,sfb09,sfb12 INTO l_sfb_qty,l_sfb09,l_sfb12
                 FROM sfb_file
                WHERE sfb01 = l_sfv.sfv11
               SELECT sma74 INTO l_percent FROM sma_file
               LET l_sfb_qty_t = l_sfb_qty * (100+l_percent)/100
               LET l_sfb_qty_t = l_sfb_qty_t - l_sfb09 - l_sfb12 
               LET l_sfb_qty = l_sfb_qty - l_sfb09 - l_sfb12
               IF l_sfv.sfv09 > l_sfb_qty_t THEN
                  CALL cl_err(l_sfv.sfv11,'REB-141',1)
                  LET g_success = 'N'
                  EXIT FOREACH
               ELSE
                  IF l_sfv.sfv09 > l_sfb_qty THEN
                     CALL cl_err(l_sfv.sfv11,'REB-142',1)
                  END IF
               END IF
               SELECT sma74 INTO l_percent FROM sma_file            #161021 BY CMP.MaX add
               LET l_min_set = l_min_set * (100+l_percent)/100    #161021 BY CMP.MaX add
#161206 BY CMP.MaX add---(E)
               IF l_sfv09 > l_min_set THEN
              #IF l_sfv09 > l_min_set AND g_sma.sma73 = 'Y' THEN   #MaX   #180725 #mark #盤虧不再入庫
                     IF g_sma.sma73 = 'Y' THEN  #MOD-8B0261 add
                        CALL cl_err(l_sfv.sfv11,'asf-668',1)
                     ELSE                                    #MOD-8B0261 add
                        CALL cl_err(l_sfv.sfv11,'asf-714',1) #MOD-8B0261 add
                     END IF   #MOD-8B0261 add
#161206 BY CMP.MaX mod---(S)
                 #161021 BY CMP.MaX mod---(S)
                     LET g_success = 'N'
                     EXIT FOREACH
#                  IF l_sfv09 > l_min_set_t THEN
#                     CALL cl_err(l_sfv.sfv11,'REB-141',1)
#                     LET g_success = 'N'
#                     EXIT FOREACH
#                  ELSE
#                     CALL cl_err(l_sfv.sfv11,'REB-142',1)
#                  END IF
#                 #161021 BY CMP.MaX mod---(E)
#161206 BY CMP.MaX mod---(E)
               END IF
            END IF
        END IF
 
        IF l_sfb.sfb93='Y' # 製程否
           #check 最終製程之總轉出量(良品轉出量+Bonus)
           THEN      #
           CALL s_schdat_max_ecm03(l_sfv.sfv11) RETURNING l_ecm012,l_ecm03  #FUN-A50066
           SELECT ecm311,ecm315 INTO l_ecm311,l_ecm315 FROM ecm_file
            WHERE ecm01=l_sfv.sfv11
             #AND ecm03= (SELECT MAX(ecm03) FROM ecm_file
             #             WHERE ecm01=l_sfv.sfv11)
              AND ecm012= l_ecm012  #FUN-A50066
              AND ecm03 = l_ecm03   #FUN-A50066

           IF STATUS THEN LET l_ecm311=0 LET l_ecm315=0 END IF
           LET l_ecm_out=l_ecm311 + l_ecm315
           IF l_sfv09 > l_ecm_out THEN
              #FUN-A80102(S)
              IF g_sma.sma1434 ='Y' THEN
                 #處理自動報工
                 IF NOT t621hcsub_gen_shb(l_sfv.*,l_sfu.sfu02,l_sfv.sfv11,l_ecm012,l_ecm03,l_sfv09-l_ecm_out) THEN
                    LET g_totsuccess='N'
                    LET g_success="Y"
                    EXIT FOREACH
                 END IF
              ELSE
              #FUN-A80102(E)
                 CALL cl_err(l_sfv.sfv03,'asf-675',1)
                 LET g_success = 'N'
                 EXIT FOREACH
              END IF
           END IF
         END IF
     END IF
 
#FUN-560195-modify
#IF l_sfb.sfb94='Y' 使用FQC功能
     IF l_sfb.sfb94='Y' AND g_sma.sma896='Y' THEN
        LET l_sfv09 = 0
        SELECT SUM(sfv09) INTO l_sfv09 FROM sfv_file,sfu_file
         WHERE sfv11 = l_sfv.sfv11
           AND sfv01 = sfu01
           AND sfv17 = l_sfv.sfv17             #No.MOD-6C0156 add
           AND sfu00 = '1'   #完工入庫
           AND sfuconf <> 'X' #FUN-660137
        IF l_sfv09 IS NULL THEN LET l_sfv09 =0 END IF
 
        SELECT qcf091 INTO l_qcf091 FROM qcf_file   # QC
         WHERE qcf01 = l_sfv.sfv17        #FUN-550085
           AND qcf09 <> '2'               #accept #NO:6872
           AND qcf14 = 'Y'
        IF l_qcf091 IS NULL THEN LET l_qcf091 = 0 END IF
 
        IF l_sfv09 > l_qcf091 THEN
           CALL cl_err(l_sfv.sfv17,'asf-660',1)
           LET g_success = 'N'
           EXIT FOREACH
        END IF
     END IF
#FUN-560195-end
 
     IF p_argv = '1' OR p_argv = '2' THEN   #完工入庫或入庫退回
        #-----更新sfb_file-----------
        LET l_sfv091 = 0
        LET l_sfv092 = 0
        LET l_sfv09 = 0
 
        # For HC -----------------------
        { 
        SELECT SUM(sfv09) INTO l_sfv091 FROM sfu_file,sfv_file
         WHERE sfv11 = l_sfv.sfv11
           AND sfu01 = sfv01
           AND sfu00 = '1'           #完工入庫
           AND sfupost = 'Y'
 
        SELECT SUM(sfv09) INTO l_sfv092 FROM sfu_file,sfv_file
         WHERE sfv11 = l_sfv.sfv11
           AND sfu01 = sfv01
           AND sfu00 = '2'           #入庫退回
           AND sfupost = 'Y'
 
        LET l_sfv09 = 0
        IF cl_null(l_sfv091) THEN LET l_sfv091 = 0 END IF
        IF cl_null(l_sfv092) THEN LET l_sfv092 = 0 END IF
 
        LET l_sfv09 = l_sfv091 - l_sfv092
        IF p_argv = '1' THEN
           UPDATE sfb_file SET sfb09 = l_sfv09,
                               sfb04 = '7'
            WHERE sfb01 = l_sfv.sfv11
           IF SQLCA.sqlcode OR SQLCA.sqlerrd[3] = 0 THEN
              CALL cl_err('upd sfb',STATUS,0)
              LET g_success = 'N'
              RETURN
            END IF
        ELSE
            IF l_sfv09<0 THEN
               CALL cl_err(l_sfv.sfv03,'asf-712',0)
               LET g_success='N'
               RETURN
            END IF
 
            UPDATE sfb_file SET sfb09 = l_sfv09
             WHERE sfb01 = l_sfv.sfv11
             IF SQLCA.sqlcode OR SQLCA.sqlerrd[3] = 0 THEN
                CALL cl_err('upd sfb',STATUS,0)
                LET g_success = 'N'
                RETURN
             END IF
        END IF
        }
         IF p_argv = '1' THEN
            UPDATE sfb_file SET sfb09 = sfb09 + l_sfv.sfv09,sfb04 = '7',
                                ta_sfb102 = ta_sfb102 - l_sfv.sfv09  # 01/09/21 By Alber Cheng
               WHERE sfb01 = l_sfv.sfv11
            IF SQLCA.sqlcode OR SQLCA.sqlerrd[3] = 0 THEN
              CALL cl_err('upd sfb',STATUS,0)
              LET g_success = 'N'
              RETURN
            END IF
         ELSE
            UPDATE sfb_file SET sfb09 = sfb09 - l_sfv.sfv09,
                                ta_sfb102 = ta_sfb102 + l_sfv.sfv09  # 01/09/21 By Alber Cheng
               WHERE sfb01 = l_sfv.sfv11
            IF SQLCA.sqlcode OR SQLCA.sqlerrd[3] = 0 THEN
               CALL cl_err('upd sfb',STATUS,0)
               LET g_success = 'N'
               RETURN
            END IF
         END IF
         # For HC -----------------------
 
     END IF
     IF SQLCA.sqlcode THEN
        CALL cl_err('upd sfb',STATUS,1)
        LET g_success = 'N'
        RETURN
     END IF
 
     IF SQLCA.sqlerrd[3]=0 THEN
        CALL cl_err('upd sfb','mfg0177',1)
        LET g_success = 'N'
        RETURN
     END IF
 
     #------
     IF p_argv = '1' OR p_argv = '2' THEN    #完工入庫或入庫退回
        #------新增工單完工統計資料檔(sfh_file)---
        INSERT INTO sfh_file(sfh01,sfh02,sfh03,sfh04,sfh05,sfh06,sfh07,sfh08,sfh09,
                             sfh10,sfh11,sfh12,sfh13,sfh14,sfh15,sfh16,sfh17,sfh18,
                              sfh91,sfh92, #No.MOD-470041
                              sfhplant,sfhlegal,     #FUN-980008 add
                              ta_sfh95,ta_sfh96,ta_sfh97)
                            VALUES (l_sfv.sfv11,l_sfu.sfu02,'3',l_sfv.sfv04,
                                    ' ',l_sfv.sfv09,l_sfv.sfv08,l_sfv.sfv05,
                                    l_sfv.sfv06,l_sfv.sfv07,' ',' ',l_sfu.sfu01,
                                    l_sfv.sfv03,0,0,0,' ',' ',' ', #NO:7166
                                    g_plant,g_legal, #FUN-980008 add
                                    0,0,l_sfu.sfu04)
        IF STATUS OR SQLCA.sqlerrd[3]=0 THEN
           CALL cl_err('ins sfh',STATUS,1) LET g_success = 'N' RETURN
        END IF
     END IF
 
     IF p_argv = '1' OR p_argv = '2' THEN
        #FUN-540055  --begin
        IF g_sma.sma115 = 'Y' THEN
           IF l_sfv.sfv32 != 0 OR l_sfv.sfv35 != 0 THEN
              CALL t621hcsub_update_du('s',l_sfu.sfu01,l_sfv.sfv03,p_argv)
           END IF
        END IF
        IF g_success='N' THEN 
           #TQC-620156...............begin
           LET g_totsuccess='N'
           LET g_success="Y"
           CONTINUE FOREACH   #No.FUN-6C0083
           #RETURN 
           #TQC-620156...............end
        END IF
        #FUN-540055  --end
        CALL t621hcsub_update_s(l_sfu.sfu01,l_sfv.sfv03,p_argv)
        IF g_success='N' THEN
           #TQC-620156...............begin
           LET g_totsuccess='N'
           LET g_success="Y"
           CONTINUE FOREACH   #No.FUN-6C0083
           #RETURN 
           #TQC-620156...............end
        END IF
     END IF
     CALL s_updsfb11(l_sfv.sfv11)     #update sfb11
     CALL t621hcsub_ins_sub_rvv(l_sfu.sfu01,l_sfv.sfv03,p_argv)  #kim:此function看似是多餘的,因為輸入工單編號時會卡不可為委外,故此function進去後一定會跳離
     IF s_industry('icd') THEN
        #FUN-810038................begin
        #完工入庫csft621hc,若入庫料號(sfv04)之料件狀態(ta_ima040) = '[3-4]', 
        #除原有異動檔處理,需增加tc_tlf_file及更新tc_img_file
        IF p_argv = '1' THEN
           CALL s_icdpost(1,l_sfv.sfv04,l_sfv.sfv05,l_sfv.sfv06,
                            l_sfv.sfv07,l_sfv.sfv08,l_sfv.sfv09,
                            l_sfv.sfv01,l_sfv.sfv03,
                            l_sfu.sfu02,'Y',l_sfv.sfv11,0)
                RETURNING l_flag
           IF l_flag = 0 THEN
              LET g_totsuccess='N'
              LET g_success="Y"
              CONTINUE FOREACH
           END IF
        END IF
        #FUN-810038................end
     END IF
  END FOREACH
 
  IF STATUS THEN
     CALL cl_err('foreach',STATUS,0)
     LET g_success='N'
  END IF
 
  #TQC-620156...............begin
  IF g_totsuccess="N" THEN
     LET g_success="N"
  END IF
 
   CALL s_showmsg()   #No.FUN-6C0083
 
  #TQC-620156...............end
  CALL cl_msg('')
 
END FUNCTION
 
#kim:此function看似是多餘的,因為輸入工單編號時會卡不可為委外,故此function進去後一定會跳離
FUNCTION t621hcsub_ins_sub_rvv(p_sfu01,p_sfv03,p_argv)
   DEFINE p_sfu01       LIKE sfu_file.sfu01
   DEFINE p_sfv03       LIKE sfv_file.sfv03
   DEFINE p_argv        LIKE type_file.chr1
   DEFINE l_sfu         RECORD LIKE sfu_file.*
   DEFINE l_sfv         RECORD LIKE sfv_file.*
   DEFINE l_pmn		RECORD LIKE pmn_file.*
   DEFINE l_sfb		RECORD LIKE sfb_file.*
   DEFINE l_rva		RECORD LIKE rva_file.*
   DEFINE l_rvb		RECORD LIKE rvb_file.*
   DEFINE l_rvu		RECORD LIKE rvu_file.*
   DEFINE l_rvv		RECORD LIKE rvv_file.*
   DEFINE l_rvvi	RECORD LIKE rvvi_file.*  #No.FUN-7B0018
   DEFINE l_rvbi	RECORD LIKE rvbi_file.*  #No.FUN-7B0018
 
   IF g_success='N' THEN RETURN END IF
   
   SELECT * INTO l_sfu.* FROM sfu_file
    WHERE sfu01 = p_sfu01
   IF SQLCA.sqlcode THEN
      CALL cl_err3('sel','sfu_file',p_sfu01,'',SQLCA.sqlcode,'','','1')
      LET g_success = 'N'
      RETURN
   END IF
   
   SELECT * INTO l_sfv.* FROM sfv_file 
    WHERE sfv01 = p_sfu01
      AND sfv03 = p_sfv03
   IF SQLCA.sqlcode THEN
      CALL cl_err3('sel','sfv_file',p_sfu01,p_sfv03,SQLCA.sqlcode,'','','1')
      LET g_success = 'N'
      RETURN
   END IF
 
   SELECT * INTO l_sfb.* FROM sfb_file
    WHERE sfb01=l_sfv.sfv11
   IF STATUS THEN CALL cl_err('s sfb:',STATUS,1) LET g_success='N' RETURN END IF
 
   IF l_sfb.sfb02<>7 THEN RETURN END IF
 
   SELECT * INTO l_pmn.* FROM pmn_file
    WHERE pmn41=l_sfv.sfv11
      AND pmn65='1'
   IF SQLCA.sqlcode  THEN
      CALL cl_err('s pmn:',STATUS,1)
      LET g_success='N'
      RETURN
   END IF
 
   UPDATE pmn_file SET pmn50=l_sfb.sfb09
    WHERE pmn01=l_pmn.pmn01 AND pmn02=l_pmn.pmn02
 
   IF SQLCA.sqlcode OR SQLCA.sqlerrd[3] = 0 THEN
      CALL cl_err3('upd','pmn_file',l_pmn.pmn01,l_pmn.pmn02,SQLCA.sqlcode,'','','1')
      LET g_success = 'N'
      RETURN
   END IF
 
   #---------------------------------------- insert rva_file (入庫時)
   IF l_sfu.sfu00='1' THEN
      INITIALIZE l_rva.* TO NULL
      LET l_rva.rva00='1'                    #FUN-940083
      LET l_rva.rva01=l_sfu.sfu01
      LET l_rva.rva04='N'
      LET l_rva.rva05=l_sfb.sfb82
      LET l_rva.rva06=l_sfu.sfu02
      LET l_rva.rva10='SUB'
      LET l_rva.rvaconf='Y'
      LET l_rva.rvaacti='Y'
      LET l_rva.rvauser=g_user
      LET g_data_plant = g_plant #FUN-980030
      LET l_rva.rvadate=TODAY
      LET l_rva.rva29=' '    #NO.FUN-960130
      LET l_rva.rvaplant = g_plant #FUN-980008 add
      LET l_rva.rvalegal = g_legal #FUN-980008 add
      LET l_rva.rvaoriu = g_user      #No.FUN-980030 10/01/04
      LET l_rva.rvaorig = g_grup      #No.FUN-980030 10/01/04
      INSERT INTO rva_file VALUES(l_rva.*)
      #---------------------------------------- insert rvb_file (入庫時)
      INITIALIZE l_rvb.* TO NULL
      LET l_rvb.rvb01=l_sfu.sfu01
      LET l_rvb.rvb02=l_sfv.sfv03
      LET l_rvb.rvb03=l_pmn.pmn02
      LET l_rvb.rvb04=l_pmn.pmn01
      LET l_rvb.rvb05=l_sfv.sfv04
      LET l_rvb.rvb06=0
      LET l_rvb.rvb07=l_sfv.sfv09
      LET l_rvb.rvb08=l_sfv.sfv09
      LET l_rvb.rvb09=l_sfv.sfv09
      LET l_rvb.rvb10=l_pmn.pmn31
      LET l_rvb.rvb18='30'
      LET l_rvb.rvb19='1'
      LET l_rvb.rvb22=l_sfv.sfv12
      LET l_rvb.rvb29=0
      LET l_rvb.rvb30=l_sfv.sfv09
      LET l_rvb.rvb31=0
      LET l_rvb.rvb34=l_sfv.sfv11
      LET l_rvb.rvb89='N'          #FUN-940083
      LET l_rvb.rvb35='N'
      LET l_rvb.rvb36=l_sfv.sfv05
      LET l_rvb.rvb37=l_sfv.sfv06
      LET l_rvb.rvb38=l_sfv.sfv07
      LET l_rvb.rvb930=l_sfv.sfv930 #FUN-670103
      LET l_rvb.rvb42 = ' '   #NO.FUN-960130
      LET l_rvb.rvbplant = g_plant #FUN-980008 add
      LET l_rvb.rvblegal = g_legal #FUN-980008 add
      INSERT INTO rvb_file VALUES(l_rvb.*)
      IF STATUS THEN
         CALL cl_err('i rvb:',STATUS,1)
         LET g_success='N'
         RETURN
      END IF
      IF NOT s_industry('std') THEN
         #No.FUN-7B0018 080306 add --begin
         INITIALIZE l_rvbi.* TO NULL
         LET l_rvbi.rvbi01 = l_rvb.rvb01
         LET l_rvbi.rvbi02 = l_rvb.rvb02
         IF NOT s_ins_rvbi(l_rvbi.*,'') THEN
            LET g_success = 'N'
            RETURN
         END IF
         #No.FUN-7B0018 080306 add --end
      END IF
   END IF
   #---------------------------------------- insert rvu_file (入/退庫)
   INITIALIZE l_rvu.* TO NULL
   IF l_sfu.sfu00='1' THEN
      LET l_rvu.rvu00='1'
   ELSE
      LET l_rvu.rvu00='3'
   END IF
 
   LET l_rvu.rvu01=l_sfu.sfu01
   LET l_rvu.rvu02=l_sfu.sfu01
   LET l_rvu.rvu03=l_sfu.sfu02
   LET l_rvu.rvu04=l_sfb.sfb82
   SELECT pmc03 INTO l_rvu.rvu05 FROM pmc_file WHERE pmc01=l_rvu.rvu04
   LET l_rvu.rvu08='SUB'
   LET l_rvu.rvuconf='Y'
   LET l_rvu.rvuacti='Y'
   LET l_rvu.rvuuser=g_user
   LET l_rvu.rvudate=TODAY
   #NO.FUN-960130-----begin-----                                                                                                 
   LET l_rvu.rvu21 = ' '                                                                                                         
   LET l_rvu.rvu900 = '0'                                                                                                        
   LET l_rvu.rvumksg = ' '                                                                                                       
   #NO.FUN-960130-----end-----
   LET l_rvu.rvuplant = g_plant #FUN-980008 add
   LET l_rvu.rvulegal = g_legal #FUN-980008 add
   LET l_rvu.rvuoriu = g_user      #No.FUN-980030 10/01/04
   LET l_rvu.rvuorig = g_grup      #No.FUN-980030 10/01/04
   LET l_rvu.rvu27 = '1'           #TQC-B60065
   INSERT INTO rvu_file VALUES(l_rvu.*)
   #---------------------------------------- insert rvv_file (入/退庫)
   INITIALIZE l_rvv.* TO NULL
   LET l_rvv.rvv01=l_sfu.sfu01
   LET l_rvv.rvv02=l_sfv.sfv03
   IF l_sfu.sfu00='1' THEN
      LET l_rvv.rvv03='1'
   ELSE
      LET l_rvv.rvv03='3'
   END IF
   LET l_rvv.rvv04=l_sfu.sfu01
   LET l_rvv.rvv05=l_sfv.sfv03
   LET l_rvv.rvv06=l_sfb.sfb82
   LET l_rvv.rvv09=l_sfu.sfu02
   LET l_rvv.rvv17=l_sfv.sfv09
   LET l_rvv.rvv18=l_sfv.sfv11
   LET l_rvv.rvv23=0
   LET l_rvv.rvv88=0           #No.TQC-7B0083
   LET l_rvv.rvv25='N'
   LET l_rvv.rvv31=l_sfv.sfv04
   SELECT ima02 INTO l_rvv.rvv031 FROM ima_file WHERE ima01=l_sfv.sfv04
   LET l_rvv.rvv32=l_sfv.sfv05
   LET l_rvv.rvv33=l_sfv.sfv06
   LET l_rvv.rvv34=l_sfv.sfv07
   LET l_rvv.rvv35=l_sfv.sfv08
   LET l_rvv.rvv35_fac=1
   LET l_rvv.rvv36=l_pmn.pmn01
   LET l_rvv.rvv37=l_pmn.pmn02
   LET l_rvv.rvv930=l_sfv.sfv930 #FUN-670103
   LET l_rvv.rvv89='N'           #FUN-940083
   IF cl_null(l_rvv.rvv02) THEN LET l_rvv.rvv02 = 1 END IF  
   LET l_rvv.rvv10 = ' '    #NO.FUN-960130
   LET l_rvv.rvvplant = g_plant #FUN-980008 add
   LET l_rvv.rvvlegal = g_legal #FUN-980008 add
   INSERT INTO rvv_file VALUES(l_rvv.*)
   IF STATUS THEN CALL cl_err('i rvv:',STATUS,1)
      LET g_success='N'
      RETURN
   END IF
   IF NOT s_industry('std') THEN
      #No.FUN-7B0018 080306 add --begin
      INITIALIZE l_rvvi.* TO NULL
      LET l_rvvi.rvvi01 = l_rvv.rvv01
      LET l_rvvi.rvvi02 = l_rvv.rvv02
      IF NOT s_ins_rvvi(l_rvvi.*,'') THEN
         LET g_success = 'N'
         RETURN
      END IF
      #No.FUN-7B0018 080306 add --end
   END IF
 
END FUNCTION
 
FUNCTION t621hcsub_w(p_sfu01,p_action_choice,p_inTransaction,p_argv)       #過帳還原
   DEFINE p_sfu01            LIKE sfu_file.sfu01
   DEFINE p_action_choice    STRING
   DEFINE p_inTransaction    LIKE type_file.num5 
   DEFINE p_argv             LIKE type_file.chr1
   DEFINE l_sfu              RECORD LIKE sfu_file.* 
   DEFINE l_sfv              RECORD LIKE sfv_file.* 
   DEFINE l_yy               LIKE type_file.num10
   DEFINE l_mm               LIKE type_file.num10
   DEFINE l_imm01            LIKE imm_file.imm01
   DEFINE l_msg              STRING
   DEFINE l_ima906           LIKE ima_file.ima906
 
 
   IF s_shut(0) THEN RETURN END IF
   IF g_success='N' THEN RETURN END IF
   
   LET g_success = 'Y'
 
   IF p_sfu01 IS NULL THEN 
      CALL cl_err('',-400,0) 
      LET g_success = 'N' 
      RETURN 
   END IF   
   
   SELECT * INTO l_sfu.* FROM sfu_file
    WHERE sfu01 = p_sfu01
   IF SQLCA.sqlcode THEN
      CALL cl_err3('sel','sfu_file',p_sfu01,'',SQLCA.sqlcode,'','','1')
      LET g_success = 'N'
      RETURN
   END IF
   
   IF l_sfu.sfupost='N' THEN 
      CALL cl_err(l_sfu.sfu01,'mfg0178',1)
      LET g_success = 'N'
      RETURN 
   END IF
 
   IF l_sfu.sfuconf = 'X' THEN 
      CALL cl_err('','9024',0) 
      LET g_success = 'N'
      RETURN 
   END IF #FUN-660137
 
   #MOD-580334...............begin
   IF NOT cl_null(l_sfu.sfu09) THEN
      CALL cl_err('','asf-622',0)
      LET g_success = 'N'
      RETURN
   END IF
   #MOD-580334...............end
 
   IF g_sma.sma53 IS NOT NULL AND l_sfu.sfu02 <= g_sma.sma53 THEN
      CALL cl_err('','mfg9999',0)
      LET g_success = 'N'
      RETURN
   END IF
 
   CALL s_yp(l_sfu.sfu02) RETURNING l_yy,l_mm
   IF (l_yy*12+l_mm) > (g_sma.sma51*12+g_sma.sma52) THEN
      CALL cl_err(l_yy,'mfg6090',0)
      LET g_success = 'N'
      RETURN
   END IF
 
   IF NOT cl_null(p_action_choice) THEN
      IF NOT cl_confirm('asf-663') THEN RETURN END IF
   END IF
 
   IF NOT p_inTransaction THEN   
      BEGIN WORK    #carrier
   END IF
 
   CALL t621hcsub_lock_cl() 
   OPEN t621hcsub_cl USING p_sfu01
   IF STATUS THEN
      CALL cl_err("OPEN t621hcsub_cl:", STATUS, 1)
      CLOSE t621hcsub_cl
      IF NOT p_inTransaction THEN ROLLBACK WORK END IF
      LET g_success='N' #FUN-730012 add
      RETURN
   END IF
 
   FETCH t621hcsub_cl INTO l_sfu.*          # 鎖住將被更改或取消的資料
   IF SQLCA.sqlcode THEN
      CALL cl_err('lock sfu:',SQLCA.sqlcode,0)     # 資料被他人LOCK
      CLOSE t621hcsub_cl
      IF NOT p_inTransaction THEN ROLLBACK WORK END IF
      LET g_success='N' #FUN-730012 add
      RETURN
   END IF
 
   CLOSE t621hcsub_cl
 
 
   UPDATE sfu_file SET sfupost='N' WHERE sfu01=l_sfu.sfu01
   IF SQLCA.sqlcode OR SQLCA.sqlerrd[3] = 0 THEN
      CALL cl_err3('upd','sfu_file',l_sfu.sfu01,'',SQLCA.sqlcode,'','','1')
      LET g_success='N'
   END IF
   #FUN-5C0114...............begin
   IF p_argv='3' THEN
      CALL t621hcsub_upd_sre11("-",l_sfu.sfu01,p_argv)
   ELSE
   #FUN-5C0114...............end
      CALL t621hcsub_w1(l_sfu.sfu01,p_argv)
   END IF

#151204 BY CMP.MaX add---(S)
   UPDATE tc_bar_file SET tc_bartcode ='1' WHERE tc_barserial IN (SELECT tc_bar_tmpserial
                                                                    FROM tc_bar_tmp_file
                                                                   WHERE tc_bar_tmpdj_serno = l_sfu.sfu01)

   IF SQLCA.sqlcode THEN
     LET g_success = 'N'
   END IF
#151204 BY CMP.MaX add---(E)

   IF sqlca.sqlcode THEN LET g_success='N' END IF
   IF g_success = 'Y' THEN
      LET l_sfu.sfupost='N'
      IF NOT p_inTransaction THEN COMMIT WORK END IF
   ELSE
      LET l_sfu.sfupost='Y'
      IF NOT p_inTransaction THEN ROLLBACK WORK END IF
   END IF
 
 
   #carrier check logical
   #-----No.FUN-610090-----
   IF l_sfu.sfupost = "Y" THEN
      DECLARE t621hcsub_s1_c2 CURSOR FOR SELECT * FROM sfv_file
        WHERE sfv01 = l_sfu.sfu01
 
      LET l_imm01 = ""
      LET g_success = "Y"
 
      CALL s_showmsg_init()   #No.FUN-6C0083 
 
      BEGIN WORK
 
      FOREACH t621hcsub_s1_c2 INTO l_sfv.*
         IF STATUS THEN
            EXIT FOREACH
         END IF
         SELECT ima906 INTO l_ima906 FROM ima_file WHERE ima01 = l_sfv.sfv04
 
         IF g_sma.sma115 = 'Y' THEN
            IF l_ima906 = '2' THEN  #子母單位
               LET g_unit_arr[1].unit= l_sfv.sfv30
               LET g_unit_arr[1].fac = l_sfv.sfv31
               LET g_unit_arr[1].qty = l_sfv.sfv32
               LET g_unit_arr[2].unit= l_sfv.sfv33
               LET g_unit_arr[2].fac = l_sfv.sfv34
               LET g_unit_arr[2].qty = l_sfv.sfv35
               CALL s_dismantle(l_sfu.sfu01,l_sfv.sfv03,l_sfu.sfu02,
                                l_sfv.sfv04,l_sfv.sfv05,l_sfv.sfv06,
                                l_sfv.sfv07,g_unit_arr,l_imm01)
                      RETURNING l_imm01
               #TQC-620156...............begin
               IF g_success='N' THEN 
                  LET g_totsuccess='N'
                  LET g_success="Y"
                  CONTINUE FOREACH   #No.FUN-6C0083
                  #RETURN 
               END IF
               #TQC-620156...............end
            END IF
         END IF
      END FOREACH
 
      #TQC-620156...............begin
      IF g_totsuccess="N" THEN
         LET g_success="N"
      END IF
 
      CALL s_showmsg()   #No.FUN-6C0083
 
      #TQC-620156...............end
      
      #180805 BY CMP.Geoffrey Add (S)
      #IF g_user = 'geoffrey' THEN
      #   CALL t621hc_undo_sfb_csfi301()
      #END IF
      #180805 BY CMP.Geoffrey Add (E)
      
      IF g_success = "Y" AND NOT cl_null(l_imm01) THEN
         COMMIT WORK
         LET l_msg="aimt324 '",l_imm01,"'"
         CALL cl_cmdrun_wait(l_msg)
      ELSE
         ROLLBACK WORK
      END IF
   END IF
   #-----No.FUN-610090 END-----
 
END FUNCTION
 
FUNCTION t621hcsub_w1(p_sfu01,p_argv)
 DEFINE p_sfu01     LIKE sfu_file.sfu01
 DEFINE p_argv      LIKE type_file.chr1
 DEFINE l_sfv       RECORD LIKE sfv_file.*
 DEFINE l_sfu       RECORD LIKE sfu_file.*
 DEFINE l_sfb       RECORD LIKE sfb_file.*
 DEFINE l_sfv091    LIKE sfv_file.sfv09
 DEFINE l_sfv092    LIKE sfv_file.sfv09
 DEFINE l_sfv09     LIKE sfv_file.sfv09
 DEFINE l_qcf091    LIKE qcf_file.qcf091
 DEFINE s_sfv09     LIKE sfv_file.sfv09
 DEFINE l_sfb04     LIKE sfb_file.sfb04
 DEFINE l_sfb39     LIKE sfb_file.sfb39
 DEFINE l_flag      LIKE type_file.num5 
 DEFINE l_ima918    LIKE ima_file.ima918
 DEFINE l_ima921    LIKE ima_file.ima921
 DEFINE la_tlf  DYNAMIC ARRAY OF RECORD LIKE tlf_file.*   #NO.FUN-8C0131 
 DEFINE l_sql   STRING                                    #NO.FUN-8C0131 
 DEFINE l_i     LIKE type_file.num5                       #NO.FUN-8C0131 
   IF g_success = 'N' THEN RETURN END IF
  
   IF p_sfu01 IS NULL THEN 
      CALL cl_err('',-400,0) 
      LET g_success = 'N' 
      RETURN 
   END IF   
   
   SELECT * INTO l_sfu.* FROM sfu_file
    WHERE sfu01 = p_sfu01
   IF SQLCA.sqlcode THEN
      CALL cl_err3('sel','sfu_file',p_sfu01,'',SQLCA.sqlcode,'','','1')
      LET g_success = 'N'
      RETURN
   END IF
  
  CALL s_showmsg_init()   #No.FUN-6C0083 
 
  DECLARE t621hcsub_w1_c CURSOR FOR
   SELECT * FROM sfv_file WHERE sfv01=l_sfu.sfu01
 
  FOREACH t621hcsub_w1_c INTO l_sfv.*
      IF STATUS THEN EXIT FOREACH END IF
      IF l_sfv.sfv09 = 0 THEN 
         CALL cl_err(l_sfv.sfv09,'asf-660',1)   #MOD-990194
         LET g_success='N'   #MOD-990194
         EXIT FOREACH 
      END IF
      IF cl_null(l_sfv.sfv04) THEN CONTINUE FOREACH END IF
 
#----No.B363
      SELECT * INTO l_sfb.* FROM sfb_file WHERE sfb01=l_sfv.sfv11
 
      IF l_sfb.sfb04='8' THEN
         CALL cl_err(l_sfb.sfb01,'mfg3430',1)
         LET g_success='N'
         EXIT FOREACH
      END IF
#----No.B363 END
 
     #-----更新sfb_file-----------
      IF p_argv = '1' OR p_argv = '2' THEN
         LET l_sfv091 = 0    LET l_sfv092 = 0  LET l_sfv09 = 0
         SELECT SUM(sfv09) INTO l_sfv091 FROM sfu_file,sfv_file
          WHERE sfv11 = l_sfv.sfv11
            AND sfu01 = sfv01
            AND sfu00 = '1'  #入庫
            AND sfupost = 'Y'
 
         SELECT SUM(sfv09) INTO l_sfv092 FROM sfu_file,sfv_file
          WHERE sfv11 = l_sfv.sfv11
            AND sfu01 = sfv01
            AND sfu00 = '2'  #退回
            AND sfupost = 'Y'
         IF cl_null(l_sfv091) THEN LET l_sfv091 = 0 END IF
         IF cl_null(l_sfv092) THEN LET l_sfv092 = 0 END IF
 
         LET l_sfv09 = l_sfv091 - l_sfv092
 
## No:2627 modify 1998/10/26 -----------
         CASE
            WHEN l_sfv09>0
                 LET l_sfb04='7'
            WHEN l_sfv09=0         #FUN-550085
                 IF l_sfv.sfv17 IS NOT NULL AND l_sfv.sfv17 <> ' ' THEN
                    LET l_sfb04='6'
                 ELSE
                   #FUN-5C0055...............begin
                   LET l_sfb39=' '
                   SELECT sfb39 INTO l_sfb39 FROM sfb_file
                     WHERE sfb01=l_sfv.sfv11
                   IF cl_null(l_sfb39) OR (l_sfb39='1') THEN
                     LET l_sfb04 = '4'
                   ELSE
                     LET l_sfb04 = '2'
                   END IF
                   #FUN-5C0055...............end
                 END IF
            WHEN l_sfv09<0
                 CALL cl_err(l_sfu.sfu01,'asf-672',1)
                 LET g_success = 'N'
                 RETURN
         END CASE

         # For HC --------------------------------
         {
         UPDATE sfb_file SET sfb09 = l_sfv09,
                             sfb04 = l_sfb04
          WHERE sfb01 = l_sfv.sfv11
         } 
         IF p_argv = '1' THEN
            UPDATE sfb_file SET sfb09 = sfb09 - l_sfv.sfv09,
                                sfb04 = l_sfb04,
                                ta_sfb102 = ta_sfb102 + l_sfv.sfv09  # 01/09/21 By Alber Cheng
               WHERE sfb01 = l_sfv.sfv11
         ELSE
            UPDATE sfb_file SET sfb09 = sfb09 + l_sfv.sfv09,
                                sfb04 = l_sfb04,
                                ta_sfb102 = ta_sfb102 - l_sfv.sfv09  # 01/09/21 By Alber Cheng
               WHERE sfb01 = l_sfv.sfv11
         END IF
         # For HC --------------------------------

         IF STATUS OR SQLCA.sqlerrd[3] = 0 THEN
            CALL cl_err('upd sfb',STATUS,0)
            LET g_success = 'N'
            RETURN
         END IF

      END IF
     #------
 
      IF p_argv = '1' OR p_argv = '2' THEN
 
         #FUN-540055  --begin
         IF g_sma.sma115 = 'Y' THEN
            IF l_sfv.sfv32 != 0 OR l_sfv.sfv35 != 0 THEN
               CALL t621hcsub_update_du('w',l_sfu.sfu01,l_sfv.sfv03,p_argv)
            END IF
         END IF
         IF g_success='N' THEN 
            #TQC-620156...............begin
            LET g_totsuccess='N'
            LET g_success="Y"
            CONTINUE FOREACH   #No.FUN-6C0083
            #RETURN 
            #TQC-620156...............end
         END IF
         #FUN-540055  --end
         CALL t621hcsub_update_w(l_sfu.sfu01,l_sfv.sfv03,p_argv)
         IF g_success='N' THEN 
           #TQC-620156...............begin
           LET g_totsuccess='N'
           LET g_success="Y"
           CONTINUE FOREACH   #No.FUN-6C0083
           #RETURN 
           #TQC-620156...............end
         END IF
      END IF
 
      CALL s_updsfb11(l_sfv.sfv11)     #update sfb11
 
      CALL t621hcsub_del_sub_rvv(l_sfv.sfv01,l_sfv.sfv03)
  ##NO.FUN-8C0131   add--begin   
        LET l_sql =  " SELECT  * FROM tlf_file ", 
                     " WHERE tlf01 = '",l_sfv.sfv04,"' ", 
                     "   AND tlf036 = '",l_sfv.sfv01,"' AND tlf037= ",l_sfv.sfv03," "
        DECLARE t621hc_u_tlf_c1 CURSOR FROM l_sql
        LET l_i = 0 
        CALL la_tlf.clear()
        FOREACH t621hc_u_tlf_c1 INTO g_tlf.*  
           LET l_i = l_i + 1
           LET la_tlf[l_i].* = g_tlf.*
        END FOREACH     

  ##NO.FUN-8C0131   add--end 
      DELETE FROM tlf_file
       WHERE tlf01 =l_sfv.sfv04
         AND (tlf036=l_sfv.sfv01 AND tlf037=l_sfv.sfv03)
      IF SQLCA.sqlcode OR SQLCA.sqlerrd[3]=0 THEN
         CALL cl_err('del tlf',STATUS,0)
         LET g_success = 'N'
         RETURN
      END IF
    ##NO.FUN-8C0131   add--begin
      FOR l_i = 1 TO la_tlf.getlength()
         LET g_tlf.* = la_tlf[l_i].*
         IF NOT s_untlf1('') THEN 
            LET g_success='N' RETURN
         END IF 
      END FOR       
  ##NO.FUN-8C0131   add--end 
 
      #-----No.FUN-810036-----
      #-----No.MOD-840216-----
      SELECT ima918,ima921 INTO l_ima918,l_ima921
        FROM ima_file
       WHERE ima01 = l_sfv.sfv04
         AND imaacti = "Y"
      
      IF l_ima918 = "Y" OR l_ima921 = "Y" THEN
      #-----No.MOD-840216 END-----
         DELETE FROM tlfs_file
          WHERE tlfs01 = l_sfv.sfv04
            AND tlfs10 = l_sfv.sfv01
            AND tlfs11 = l_sfv.sfv03
        
         IF SQLCA.sqlcode OR SQLCA.sqlerrd[3]=0 THEN
            CALL cl_err('del tlfs',STATUS,0)
            LET g_success = 'N'
            RETURN
         END IF
      END IF   #No.MOD-840216
      #-----No.FUN-810036 END-----
 
      IF p_argv = '1' OR p_argv = '2' THEN    #完工入庫或入庫退回
         #刪除工單完工統計資料檔(sfh_file)
         DELETE FROM sfh_file WHERE sfh01= l_sfv.sfv11 #工單編號
                                AND sfh13= l_sfu.sfu01 #入庫單號
                                AND sfh14= l_sfv.sfv03 #序次    #NO:7166
         IF STATUS OR SQLCA.sqlerrd[3] = 0 THEN
            CALL cl_err('del sfh',SQLCA.sqlcode,1)
            LET g_success = 'N'
            RETURN
         END IF
      END IF
      IF s_industry("icd") THEN
         #FUN-810038................begin
         #完工入庫csft621hc,若入庫料號(sfv04)之料件狀態(ta_ima040) = '[3-4]',
         #除原有異動檔處理,需增加tc_tlf_file及更新tc_img_file
         IF p_argv = '1' THEN
            CALL s_icdpost(1,l_sfv.sfv04,l_sfv.sfv05,l_sfv.sfv06,
                             l_sfv.sfv07,l_sfv.sfv08,l_sfv.sfv09,
                             l_sfv.sfv01,l_sfv.sfv03,
                             l_sfu.sfu02,'N',l_sfv.sfv11,0)
                 RETURNING l_flag
            IF l_flag = 0 THEN
               LET g_totsuccess='N'
               LET g_success="Y"
               CONTINUE FOREACH
            END IF
         END IF
         #FUN-810038................end
      END IF
  END FOREACH
  #TQC-620156...............begin
  IF g_totsuccess="N" THEN
     LET g_success="N"
  END IF
 
  CALL s_showmsg()   #No.FUN-6C0083
 
  #TQC-620156...............end
END FUNCTION
 
FUNCTION t621hcsub_del_sub_rvv(p_sfu01,p_sfv03)
   DEFINE p_sfu01     LIKE sfu_file.sfu01
   DEFINE p_sfv03     LIKE sfv_file.sfv03
   DEFINE l_sfv       RECORD LIKE sfv_file.*
   DEFINE l_sfu       RECORD LIKE sfu_file.*
   DEFINE l_pmn       RECORD LIKE pmn_file.*
   DEFINE l_sfb       RECORD LIKE sfb_file.*
   DEFINE l_rva       RECORD LIKE rva_file.*
   DEFINE l_rvb       RECORD LIKE rvb_file.*
   DEFINE l_rvu       RECORD LIKE rvu_file.*
   DEFINE l_rvv       RECORD LIKE rvv_file.*
   DEFINE l_rvv23     LIKE rvv_file.rvv23
 
   IF g_success = 'N' THEN RETURN END IF
  
   IF p_sfu01 IS NULL THEN 
      CALL cl_err('',-400,0) 
      LET g_success = 'N' 
      RETURN 
   END IF   
   
   SELECT * INTO l_sfu.* FROM sfu_file
    WHERE sfu01 = p_sfu01
   IF SQLCA.sqlcode THEN
      CALL cl_err3('sel','sfu_file',p_sfu01,'',SQLCA.sqlcode,'','','1')
      LET g_success = 'N'
      RETURN
   END IF
 
   SELECT * INTO l_sfv.* FROM sfv_file
    WHERE sfv01 = p_sfu01
      AND sfv03 = p_sfv03
   IF SQLCA.sqlcode THEN
      CALL cl_err3('sel','sfv_file',p_sfu01,p_sfv03,SQLCA.sqlcode,'','','1')
      LET g_success = 'N'
      RETURN
   END IF
 
   SELECT * INTO l_sfb.* FROM sfb_file WHERE sfb01=l_sfv.sfv11
   IF STATUS THEN CALL cl_err('s sfb:',STATUS,1)LET g_success='N' RETURN END IF
   IF l_sfb.sfb02<>7 THEN RETURN END IF
 
   SELECT * INTO l_pmn.* FROM pmn_file
    WHERE pmn41=l_sfv.sfv11
      AND pmn65='1'
   IF STATUS THEN
      CALL cl_err('s pmn:',STATUS,1)
      LET g_success='N'
      RETURN
   END IF
 
   UPDATE pmn_file SET pmn50=l_sfb.sfb09
    WHERE pmn01=l_pmn.pmn01 AND pmn02=l_pmn.pmn02
   IF SQLCA.sqlcode OR SQLCA.sqlerrd[3] = 0 THEN
      LET g_success = 'N'
      RETURN
   END IF
 
   LET l_rvv23=0
   SELECT rvv23 INTO l_rvv23 FROM rvv_file
    WHERE rvv01=l_sfv.sfv01 AND rvv02=l_sfv.sfv03
   IF l_rvv23 > 0 THEN
      CALL cl_err('rvv23>0:','aap-172',1)
      LET g_success='N' RETURN
   END IF
 
   DELETE FROM rva_file WHERE rva01=l_sfu.sfu01
   IF SQLCA.sqlcode THEN
      CALL cl_err('d rva:',STATUS,1)
      LET g_success='N' RETURN
   END IF
 
   DELETE FROM rvb_file WHERE rvb01=l_sfu.sfu01
   IF SQLCA.sqlcode THEN
      CALL cl_err('d rvb:',STATUS,1)
      LET g_success='N' RETURN
   END IF
 
   IF NOT s_industry('std') THEN
      #No.FUN-7B0018 080306 add --begin
      IF NOT s_del_rvbi(l_sfu.sfu01,'','') THEN
         LET g_success = 'N'
         RETURN
      END IF
      #No.FUN-7B0018 080306 add --end
   END IF
 
   DELETE FROM rvu_file WHERE rvu01=l_sfu.sfu01
   IF SQLCA.sqlcode THEN
      CALL cl_err('d rvu:',STATUS,1)
      LET g_success='N' RETURN
   END IF
 
   DELETE FROM rvv_file WHERE rvv01=l_sfu.sfu01
   IF STATUS THEN
      CALL cl_err('d rvv:',STATUS,1)
      LET g_success='N'
      RETURN
   END IF
   
   IF NOT s_industry('std') THEN
      #No.FUN-7B0018 080306 add --begin
      IF NOT s_del_rvvi(l_sfu.sfu01,'','') THEN
         LET g_success = 'N'
         RETURN
      END IF
      #No.FUN-7B0018 080306 add --end
   END IF
END FUNCTION

#FUN-A80102(S)
FUNCTION t621hcsub_gen_shb(l_sfv,l_sfu02,l_sfv11,l_ecm012,l_ecm03,l_shb111)
   DEFINE l_sfv RECORD LIKE sfv_file.*
   DEFINE l_shb RECORD LIKE shb_file.*
   DEFINE l_ecm RECORD LIKE ecm_file.*
   DEFINE l_sql      STRING
   DEFINE l_t1       LIKE type_file.chr5 
   DEFINE l_sfu02    LIKE sfu_file.sfu02
   DEFINE l_sfv11    LIKE sfv_file.sfv11
   DEFINE l_shb031   LIKE shb_file.shb031
   DEFINE l_ecm012   LIKE ecm_file.ecm012
   DEFINE l_ecm03    LIKE ecm_file.ecm03 
   DEFINE l_shb111   LIKE shb_file.shb111
   DEFINE li_result   LIKE type_file.num5
   DEFINE l_factor    LIKE ecm_file.ecm59
   DEFINE l_ima55     LIKE ima_file.ima55
   DEFINE l_i         LIKE type_file.num5

   INITIALIZE l_shb.* TO NULL
   SELECT * INTO l_ecm.* FROM ecm_file
    WHERE ecm01  = l_sfv11
      AND ecm012 = l_ecm012
      AND ecm03  = l_ecm03

   LET l_t1 = s_get_doc_no(l_sfv.sfv01)

   LET l_sql = "SELECT smyslip FROM smy_file WHERE smy67 = '",l_t1,"'"
   LET l_t1=NULL
   PREPARE t621hc_s1_p1 FROM l_sql
   DECLARE t621hc_s1_c1 CURSOR FOR t621hc_s1_p1
   OPEN t621hc_s1_c1
   FETCH t621hc_s1_c1 INTO l_t1
   CLOSE t621hc_s1_c1
   IF cl_null(l_t1) THEN
      LET g_success='N'
      CALL cl_err(l_sfv.sfv11,'asf-151',1)
      RETURN FALSE
   END IF
   LET l_shb.shb01  = l_t1
   LET l_shb.shb03  = l_sfu02
   LET l_shb.shb05  = l_sfv.sfv11
   LET l_shb.shb06  = l_ecm.ecm03
   LET l_shb.shb012 = l_ecm.ecm012
   LET l_shb.shb111 = 0
   LET l_shb.shb113 = 0
   LET l_shb.shb112 = 0
   LET l_shb.shb114 = 0
   LET l_shb.shb115 = 0
   LET l_shb.shb17  = 0
   IF l_ecm.ecm52='Y' THEN  #FUN-A90057
      LET l_shb.shb27  = l_ecm.ecm67
   END IF
   IF l_ecm.ecm62 IS NULL THEN LET l_ecm.ecm62 = 1 END IF
   IF l_ecm.ecm63 IS NULL THEN LET l_ecm.ecm63 = 1 END IF
   LET l_shb.shb02   = g_today
   LET l_shb031 = TIME
   LET l_shb.shb021  = l_shb031[1,5]  #TQC-B20107
   LET l_shb.shb031  = l_shb031[1,5]
   LET l_shb.shb032  = 0  #TQC-B20107
   LET l_shb.shb033  = 0  #TQC-B20107
   LET l_shb.shbinp  = g_today
   LET l_shb.shbacti = 'Y'
   LET l_shb.shbuser = g_user
   LET l_shb.shboriu = g_user
   LET l_shb.shborig = g_grup
   LET g_data_plant = g_plant
   LET l_shb.shbgrup = g_grup
   LET l_shb.shbmodu = ''
   LET l_shb.shbdate = ''
   LET l_shb.shbplant = g_plant
   LET l_shb.shblegal = g_legal
   LET l_shb.shb04 = g_user

   LET l_shb.shb111 = l_shb111 * l_ecm.ecm62 / l_ecm.ecm63
   
   CALL s_auto_assign_no("asf",l_shb.shb01,l_shb.shb03,"9","shb_file","shb01","","","")
      RETURNING li_result,l_shb.shb01
   IF (NOT li_result) THEN
      RETURN FALSE
   END IF

   LET l_shb.shb012 = l_ecm.ecm012
   LET l_shb.shb06  = l_ecm.ecm03
   LET l_shb.shb081 = l_ecm.ecm04

   IF l_shb.shb012 IS NULL THEN LET l_shb.shb012=' ' END IF

   #將ecm相關欄位帶入shb
   CALL t700sub_shb081(l_shb.*,l_ecm.*,l_shb.*) 
      RETURNING l_i,l_shb.*,l_ecm.*

   IF l_i = 1 THEN  #有錯誤
      RETURN FALSE
   END IF

   IF g_sma.sma1435='N' THEN
      LET l_shb.shb032 = (l_shb.shb111+l_shb.shb112+l_shb.shb113+l_shb.shb114+l_shb.shb115) * l_ecm.ecm14 / 60
      LET l_shb.shb033 = (l_shb.shb111+l_shb.shb112+l_shb.shb113+l_shb.shb114+l_shb.shb115) * l_ecm.ecm16 / 60
   END IF

   LET l_shb.shb30 = 'Y'
   CALL t700sub_shb26_31(l_shb.shb05,l_shb.shb012,l_shb.shb06) 
      RETURNING l_shb.shb26,l_shb.shb31
   INSERT INTO shb_file VALUES (l_shb.*)
   IF SQLCA.sqlcode THEN
      CALL cl_err(l_shb.shb05,SQLCA.sqlcode,1)
      RETURN FALSE
   END IF

   CALL cl_flow_notify(l_shb.shb01,'I')

   IF g_sma.sma1431='Y' THEN
      CALL t700sub_auto_report(l_shb.*,l_ecm.*)
   END IF

   IF g_success = 'Y' THEN   #TQC-B20107
      CALL t700sub_upd_ecm('a',l_shb.*)    # Update 製程追蹤檔
        RETURNING l_shb.*
   END IF

   IF g_success='N' THEN
      RETURN FALSE
   END IF

   IF l_shb.shb112 > 0 THEN    #表示有報廢數量
      SELECT ima55 INTO l_ima55 FROM ima_file 
       WHERE ima01= l_shb.shb10

      CALL s_umfchk(l_shb.shb10,l_ecm.ecm58,l_ima55)                                                   
               RETURNING l_i,l_factor

      IF l_i = '1' THEN                                                                                             
         LET l_factor = 1
      END IF
      UPDATE sfb_file SET sfb12 = sfb12 + (l_shb.shb112 * l_factor)
       WHERE sfb01 = l_shb.shb05 
      IF SQLCA.sqlerrd[3] = 0  THEN 
         CALL cl_err(l_shb.shb05,'asf-861',1)
         RETURN FALSE
      END IF
   END IF
   RETURN TRUE
END FUNCTION
#FUN-A80102(E)
#15/2/6 Add By Emily.Lin (S)

FUNCTION t621hcsub_y_updb(p_wc2)              #lgj 审核

  DEFINE p_wc2           LIKE type_file.chr1000 #No.FUN-690026 VARCHAR(200)
  DEFINE l_sql   LIKE type_file.chr1000
  DEFINE l_bartmp RECORD     LIKE tc_bar_tmp_file.*  
  DEFINE l_tc_basdj_imd01    LIKE tc_bas_file.tc_basdj_imd01
  
  LET l_sql ="SELECT * FROM tc_bar_tmp_file WHERE tc_bar_tmpdj_serno = '",
             p_wc2 CLIPPED,
             "'"
     
  PREPARE t621hcsub_y_updb_p FROM l_sql
  DECLARE t621hcsub_y_updb_c CURSOR FOR t621hcsub_y_updb_p
   
  INITIALIZE l_bartmp.* TO NULL

  FOREACH t621hcsub_y_updb_c INTO l_bartmp.*
     IF STATUS THEN EXIT FOREACH END IF

     UPDATE tc_bar_file SET tc_bartcode ='2' WHERE tc_barserial=l_bartmp.tc_bar_tmpserial

     IF SQLCA.sqlcode THEN
        ROLLBACK WORK
        RETURN 'N'
     END IF
     
    # UPDATE tc_bat_file SET tc_battcode ='2',tc_battdate=g_today,tc_batserno=l_bartmp.tc_bar_tmpdj_serno WHERE tc_batserial=l_bartmp.tc_bar_tmpserial and tc_batcode1 in ('101','102','201')

     IF SQLCA.sqlcode THEN
        ROLLBACK WORK
        RETURN 'N'
     END IF
     SELECT sfv05 into l_tc_basdj_imd01 FROM sfv_file where sfv01=l_bartmp.tc_bar_tmpdj_serno and sfv03=l_bartmp.tc_bar_tmpdj_item     
     INSERT INTO tc_bas_file (tc_basserial,tc_basdj_serno,tc_basdj_tcode,tc_basdj_item,tc_bas_qty,tc_basdj_imd01)
            VALUES (l_bartmp.tc_bar_tmpserial,l_bartmp.tc_bar_tmpdj_serno,'101',l_bartmp.tc_bar_tmpdj_item,l_bartmp.tc_bar_tmpqty,l_tc_basdj_imd01)

     IF SQLCA.sqlcode THEN
        ROLLBACK WORK
        RETURN 'N'
     END IF
  END FOREACH 

  DELETE FROM tc_bar_tmp_file WHERE tc_bar_tmpdj_serno = l_bartmp.tc_bar_tmpdj_serno

  IF SQLCA.sqlcode THEN
     ROLLBACK WORK
     RETURN 'N'
  END IF  
                                                             
  RETURN 'Y'
END FUNCTION

FUNCTION t621hcsub_n_updb(p_wc2)              #lgj取消审核
  DEFINE p_wc2           LIKE type_file.chr1000 #No.FUN-690026 VARCHAR(200)
  DEFINE l_sql   LIKE type_file.chr1000
  DEFINE l_bartmp RECORD     LIKE tc_bas_file.*  

  LET l_sql ="SELECT * FROM tc_bas_file WHERE tc_basdj_serno = '",
             p_wc2 CLIPPED,
             "'"

  PREPARE t621hcsub_n_updb_p FROM l_sql
  DECLARE t621hcsub_n_updb_c CURSOR FOR t621hcsub_n_updb_p
   
  INITIALIZE l_bartmp.* TO NULL
   
  FOREACH t621hcsub_n_updb_c INTO l_bartmp.*
     IF STATUS THEN EXIT FOREACH END IF

     UPDATE tc_bar_file SET tc_bartcode ='1' WHERE tc_barserial=l_bartmp.tc_basserial
 
     IF SQLCA.sqlcode THEN
        ROLLBACK WORK
        RETURN 'N'
     END IF
     
    # UPDATE tc_bat_file SET tc_battcode ='1',tc_battdate=null,tc_batserno=null WHERE tc_batserial=l_bartmp.tc_basserial and tc_batcode1 in ('101','102','201')
 
     IF SQLCA.sqlcode THEN
        ROLLBACK WORK
        RETURN 'N'
     END IF     
     
     INSERT INTO tc_bar_tmp_file (tc_bar_tmpserial,tc_bar_tmpdj_serno,tc_bar_tmpdj_item,tc_bar_tmpqty)
            VALUES (l_bartmp.tc_basserial,l_bartmp.tc_basdj_serno,l_bartmp.tc_basdj_item,l_bartmp.tc_bas_qty)

     IF SQLCA.sqlcode THEN
        ROLLBACK WORK
        RETURN 'N'
     END IF
  END FOREACH 

  DELETE FROM tc_bas_file WHERE tc_basdj_serno= l_bartmp.tc_basdj_serno
  
  IF SQLCA.sqlcode THEN
     ROLLBACK WORK
     RETURN 'N'
  END IF   
                                                               
  RETURN 'Y'
END FUNCTION
#15/2/6 Add By Emily.Lin (E)
#180731 BY CMP.Geoffrey (S)
FUNCTION t621hc_gen_sfb_csfi301()
   DEFINE l_sql           STRING
   DEFINE l_sfv04      LIKE sfv_file.sfv04     #料號
   DEFINE l_sfv11      LIKE sfv_file.sfv11     #工單單號
   DEFINE l_sfv07      LIKE sfv_file.sfv07     #生產批號
   DEFINE l_sum_sfv09  LIKE sfv_file.sfv09     #數量(PCS)
   #DEFINE l_tc_scd24_sum  LIKE tc_scd_file.tc_scd24     #不良品數
   #DEFINE l_tc_scd25      LIKE tc_scd_file.tc_scd25     #工單號碼
   #DEFINE l_sfu01         LIKE sfu_file.sfu01
   DEFINE l_sfp01         LIKE sfp_file.sfp01
   #DEFINE l_gui_type      LIKE type_file.chr1 
   #DEFINE l_bgjob         LIKE type_file.chr1 
   #DEFINE l_bgerr         LIKE type_file.chr1 
   #DEFINE l_prog          LIKE type_file.chr10
   DEFINE l_sfp           RECORD LIKE sfp_file.*
   DEFINE l_n             LIKE type_file.num5,
          l_sfv03         LIKE sfv_file.sfv03

   #IF cl_null(g_tc_scc.tc_scc01) THEN
   #   CALL cl_err("",-400,0)
   #   RETURN
   #END IF

   LET g_errno = ''

   #SELECT * 
   #  INTO g_tc_scc.* 
   #  FROM tc_scc_file
   # WHERE tc_scc01 = g_tc_scc.tc_scc01  
   #   AND tc_scc02 = g_tc_scc.tc_scc02 
   #   AND tc_scc03 = g_tc_scc.tc_scc03 
   #   AND tc_scc04 = g_tc_scc.tc_scc04 
   #   AND tc_scc05 = g_tc_scc.tc_scc05 

   #IF g_tc_scc.tc_sccconf = 'N' THEN
   #   CALL cl_err('','art-656',1)    #此筆資料未確認
   #   RETURN
   #END IF
   #IF g_tc_scc.tc_sccconf = 'X' THEN
   #   CALL cl_err('','9024',1)       #此筆資料已作廢
   #   RETURN
   #END IF
   #IF g_tc_scc.tc_sccpost = 'Y' THEN
   #   CALL cl_err('','CMP0209',1)    #此整理日報已產生過入庫/不良品單,請查核!
   #   RETURN
   #END IF 

   #170525 By CMP.Seiman -----(S)
   LET l_n = 0
   #SELECT COUNT(*) 
   #  INTO l_n
   #  FROM tc_scd_file
   # WHERE tc_scd01 = g_tc_scc.tc_scc01
   #   AND tc_scd02 = g_tc_scc.tc_scc02
   #   AND tc_scd03 = g_tc_scc.tc_scc03
   #   AND tc_scd04 = g_tc_scc.tc_scc04
   #   AND tc_scd05 = g_tc_scc.tc_scc05
   #   AND tc_scd07 NOT LIKE '%D' 
   #IF l_n > 0 THEN
   #   CALL cl_err('','CMP0249',1)    #單身存在非D結尾料號,不可過帳!
   #   RETURN
   #END IF
   #170525 By CMP.Seiman -----(E)

   #IF NOT cl_confirm('CMP0210') THEN   #是否確認產生入庫/不良品單(Y/N)?
   #   RETURN 
   #END IF
   LET gi_err_code = ''
   #CALL s_showmsg_init() 
   LET g_data_cnt=0
   BEGIN WORK
   #LET g_success = 'Y'
   
   #XW8工單
   LET l_sql = "SELECT sfv04,sfv11,sfv07,SUM(sfv09),sfv03 ",
               "  FROM sfv_file ",
               " WHERE sfv01 = ? ",
               "   AND sfv05 = 'BA' ",
               "   AND substr(sfv11,1,3) = 'XW8' ",
               " GROUP BY sfv04,sfv11,sfv07,sfv08,sfv03 "
   PREPARE t621hc_sel_sfv_p2 FROM l_sql
   DECLARE t621hc_sel_sfv_cs2 CURSOR FOR t621hc_sel_sfv_p2
   
   WHILE TRUE 
   
      LET l_sfv04 = ''
      LET l_sfv11 = ''
      LET l_sfv07 = ''
      LET l_sum_sfv09 = ''
      LET l_sfv03 = ''
      #加工工單依照料號+工單+生產批號分群開立
      FOREACH t621hc_sel_sfv_cs2 USING g_sfu.sfu01
                                  INTO l_sfv04, l_sfv11, l_sfv07, l_sum_sfv09, l_sfv03
         IF SQLCA.sqlcode THEN
            CALL s_errmsg('','','t621hc_sel_sfv_cs2(foreach):',SQLCA.sqlcode,1) 
            LET g_success = 'N'
            EXIT FOREACH
         END IF
         
         #產生加工工單
         LET g_prog = 'csfi301'
         CALL t621hc_gen_wo(l_sfv04, l_sfv07, l_sum_sfv09, l_sfv11)
         IF l_gen_YN = 'N' THEN CONTINUE FOREACH END IF
         IF g_success = 'N' THEN
            EXIT FOREACH
         END IF
      
         #加工工單確認
         CALL i301sub_firm1_chk(g_sfb.sfb01,TRUE)
         IF g_success = 'N' THEN 
            IF cl_null(gi_err_code) THEN
               LET gi_err_code = 'CMP0281'   #加工工單自動確認失敗  
            END IF
            CALL s_errmsg('sfb01',g_sfb.sfb01,'',gi_err_code,1)   
            CALL s_errmsg('sfb01',g_sfb.sfb01,'','CMP0281',1)    #加工工單自動確認失敗   
            EXIT FOREACH
         END IF
         
         CALL i301sub_firm1_upd(g_sfb.sfb01,'',TRUE)
         IF g_success = 'N' THEN 
            IF cl_null(gi_err_code) THEN
               LET gi_err_code = 'CMP0281'   #加工工單自動確認失敗 
            END IF
            CALL s_errmsg('sfb01',g_sfb.sfb01,'',gi_err_code,1)    
            CALL s_errmsg('sfb01',g_sfb.sfb01,'','CMP0281',1)    #加工工單自動確認失敗
            EXIT FOREACH            
         END IF
         
         #產生加工發料單
         LET g_prog = 'asfi511'
         CALL t621hc_gen_sfp() RETURNING l_sfp01
         IF g_success = 'N' THEN
            EXIT FOREACH
         END IF
         
         #加工發料單確認
         CALL i501sub_y_chk(l_sfp01)    #Geoffrey 這邊我看了，都是檢查一些發料條件，並無新增／更改任何資料
         IF g_success = 'N' THEN 
            IF cl_null(gi_err_code) THEN
               LET gi_err_code = 'CMP0282'   #加工發料單自動確認失敗
            END IF
            CALL s_errmsg('sfp01',l_sfp01,'',gi_err_code,1)   
            CALL s_errmsg('sfp01',l_sfp01,'','CMP0282',1)    #加工發料單自動確認失敗
            EXIT FOREACH     
         END IF
         
         CALL i501sub_y_upd(l_sfp01,NULL,TRUE) RETURNING l_sfp.*   #Geoffrey加工發料確認 & 已核准
         IF g_success = 'N' THEN 
            IF cl_null(gi_err_code) THEN
              LET gi_err_code = 'CMP0282'   #加工發料單自動確認失敗
            END IF
            CALL s_errmsg('sfp01',l_sfp01,'',gi_err_code,1)  
            CALL s_errmsg('sfp01',l_sfp01,'','CMP0282',1)    #加工發料單自動確認失敗
            EXIT FOREACH     
         END IF
         
         #加工發料單過帳
         #CALL i501sub_s('1',l_sfp01,TRUE,'N')    #Geoffrey 更新發料單 - 扣帳碼、扣帳日期(sfp04, sfp03)；加工工單 - 依發料單去更新工單的狀態／確認否／發料套數…(sfb04, sfb87, sfb88, sfb25, sfb081)；更新img_file資料；更新sfa_file資料；
         #IF g_success = 'N' THEN 
         #   IF cl_null(gi_err_code) THEN
         #      LET gi_err_code = 'CMP0283'   #加工發料單自動過帳失敗
         #   END IF
         #   CALL s_errmsg('sfp01',l_sfp01,'',gi_err_code,1)   
         #   CALL s_errmsg('sfp01',l_sfp01,'','CMP0283',1)    #加工發料單自動過帳失敗
         #   EXIT FOREACH  
         #END IF

         UPDATE sfv_file
            SET sfvud04 = g_sfb.sfb01, sfvud05 = l_sfp01
          WHERE sfv11 = l_sfv11
            AND sfv03 = l_sfv03
        
      END FOREACH
      IF g_success = 'N' THEN
         EXIT WHILE
      END IF
       
      #成功產生單據回寫單頭做記錄
      #UPDATE tc_scc_file SET tc_sccpost='Y',
      #                       tc_sccmodu = g_user,
      #                       tc_sccdate = g_today
      # WHERE tc_scc01 = g_tc_scc.tc_scc01
      #   AND tc_scc02 = g_tc_scc.tc_scc02
      #   AND tc_scc03 = g_tc_scc.tc_scc03
	  # 	AND tc_scc04 = g_tc_scc.tc_scc04
	  # 	AND tc_scc05 = g_tc_scc.tc_scc05
      #IF SQLCA.sqlcode OR SQLCA.sqlerrd[3]=0 THEN
      #   IF SQLCA.sqlcode = 0 THEN
      #      LET SQLCA.sqlcode = 9050
      #   END IF
      #   CALL cl_err3("upd","tc_scc_file",g_tc_scc.tc_scc01,"",SQLCA.sqlcode,"","upd tc_sccpost",1)
      #   LET g_success='N'
      #END IF

      LET g_data_cnt=g_data_cnt+1
      
      EXIT WHILE
   END WHILE
   
   #LET g_gui_type = l_gui_type
   #LET g_bgjob = l_bgjob 
   #LET g_bgerr = l_bgerr 
   #LET g_prog = l_prog 
   
   #無符合條件時
   IF g_data_cnt = 0 AND g_success = 'Y' THEN
      CALL s_errmsg('','','','mfg3160',1)
      LET g_success = "N"
   END IF
   IF g_success = 'N' THEN
      ROLLBACK WORK 
   END IF
   #IF g_success = 'Y' THEN
   #   COMMIT WORK
   #   CALL s_errmsg('tc_scc01',g_tc_scc.tc_scc01,'','axc-709',2)
   #ELSE
   #   ROLLBACK WORK
   #END IF

   #CLOSE t621_cl
   #CALL s_showmsg()

   #CALL t621_show()
   
END FUNCTION

#產生加工工單
FUNCTION t621hc_gen_wo(p_sfv04, p_sfv07, p_sum_sfv09, p_sfv11)    #p_tc_scd07,p_tc_scd09,p_tc_scd10,p_tc_scd25)
   #DEFINE p_tc_scd07       LIKE tc_scd_file.tc_scd07     #品號
   #DEFINE p_tc_scd09       LIKE tc_scd_file.tc_scd09     #生產批號
   #DEFINE p_tc_scd10       LIKE tc_scd_file.tc_scd10     #完成數量
   #DEFINE p_tc_scd25       LIKE tc_scd_file.tc_scd25     #造型工單 170830 By CMP.Seiman add
   DEFINE p_sfv04          LIKE sfv_file.sfv04     #料號
   DEFINE p_sfv11          LIKE sfv_file.sfv11     #工單單號
   DEFINE p_sfv07          LIKE sfv_file.sfv07     #生產批號
   DEFINE p_sum_sfv09      LIKE sfv_file.sfv09     #數量(PCS)
   DEFINE l_bma01          LIKE bma_file.bma01   
   DEFINE li_result        LIKE type_file.num5
   DEFINE l_ima08          LIKE ima_file.ima08    #來源碼
   DEFINE p_row,p_col       LIKE type_file.num5
   DEFINE l_temp  DYNAMIC ARRAY OF RECORD
             bma01           LIKE bma_file.bma01,
             ima08           LIKE ima_file.ima08,
             ima02           LIKE ima_file.ima02
          END RECORD
          
          
   LET g_errno = ''
   LET l_gen_YN = 'Y'
   WHILE TRUE 
      CALL t621hc_sfb_init()
      LET l_bma01 = ''
      #抓取料號上階料為加工／委外工單生產料號，取得來源碼判斷單別
      SELECT bma01, ima08
        INTO l_bma01, l_ima08
        FROM bma_file, bmb_file, ima_file
       WHERE bma01 = bmb01 AND ima01 = bma01
         AND bmb03 = p_sfv04
         AND bma06 = bmb29
         AND bmb29 = ' '            #特性代碼
         AND (bmb04 <= g_today OR bmb04 IS NULL)
         AND (bmb05 > g_today OR bmb05 IS NULL)
         AND ima08 = 'M'

      IF SQLCA.sqlcode THEN
         #CALL s_errmsg('sfb01',g_sfb.sfb01,'ins sfb_file:',SQLCA.sqlcode,1)
         #LET g_success = 'N'
         #LET l_gen_YN = 'N'
         #EXIT WHILE
      #END IF

      IF sqlca.sqlerrd[2] = -1 THEN
         #LET l_gen_YN = 'N'
         #若是多個料號，就開窗選取--------------------------
         CALL cq_bma_ima_a(FALSE,FALSE,p_sfv04) RETURNING l_bma01
         LET l_ima08 = 'M'         {
         OPEN WINDOW t621hc_w_p AT p_row,p_col WITH FORM "csf/42f/csft621hc_ima"
         ATTRIBUTE (STYLE = g_win_style CLIPPED)
         CALL cl_ui_locale('csft621hc_ima')

         LET g_sql = " SELECT bma01, ima08, ima02 ",
                     "   FROM bma_file, bmb_file, ima_file ",
                     "  WHERE bmb03 = '", p_sfv04 , "'",
                     "    AND bma01 = bmb01 AND ima01 = bma01 ",
                     "    AND bma06 = bmb29 ",
                     "    AND bmb29 = ' ' ",
                     "    AND (bmb04 <= to_date('", g_today, "','YYYY-MM-DD') OR bmb04 IS NULL) ",
                     "    AND (bmb05 > to_date('", g_today, "','YYYY-MM-DD') OR bmb05 IS NULL) "
                     #"    AND AND ima08 = 'M' "

         PREPARE bma_ima_pre FROM g_sql
         DECLARE bma_ima_cs CURSOR FOR bma_ima_pre

         LET g_cnt = 1
         FOREACH bma_ima_cs INTO l_temp[g_cnt].*
            IF SQLCA.sqlcode THEN
               CALL cl_err('','',0)
               EXIT FOREACH
            END IF
            
            LET g_cnt = g_cnt + 1
            
            IF g_cnt > g_max_rec THEN
               CALL cl_err( '', 9035, 0 )
               EXIT FOREACH
            END IF 
         END FOREACH

         CALL l_temp.deleteElement(g_cnt)
         LET g_rec_b = g_cnt - 1
         LET g_cnt = 0

         DISPLAY ARRAY l_temp TO s_bma_ima.* ATTRIBUTE(COUNT=g_rec_b,UNBUFFERED)
            BEFORE DISPLAY
            EXIT DISPLAY
         END DISPLAY

         CLOSE WINDOW t621hc_w_p
         RETURN l_temp[g_cnt].bma01
         LET l_bma01 = l_temp[g_cnt].bma01
         LET l_ima08 = l_temp[g_cnt].ima08
         #g_tc_bar_tmp[l_ac].tc_bar_tmpserial
         #EXIT WHILE
         }
         ELSE
            LET l_gen_YN = 'N'
            EXIT WHILE
         END IF
      END IF
      
      IF NOT cl_null(l_bma01) THEN
         LET g_sfb.sfb05 = l_bma01
      ELSE
         CALL s_errmsg('tc_scd07',p_sfv04,'','mfg2744',1)   #在BOM中找不到此主件料號,請查核...!
         LET g_success = 'N'
         EXIT WHILE
      END IF

      #IF l_ima08 = 'M' THEN
         LET g_sfb.sfb01 = 'BW2'                  #加工工單(系統用)
      #ELSE
      #   LET g_sfb.sfb01 = 'BW4'                  #委外工單(系統用)
      #END IF
       
      LET g_sfb.sfb08 = p_sum_sfv09
      LET g_sfb.sfb98 = 'CT5'                  #成本中心(加工／委外工單為成本中心5)
      LET g_sfb.sfb23 = 'Y'                    #備料產生否
      LET g_sfb.ta_sfb02 = p_sfv07             #生產批號
      LET g_sfb.ta_sfb04 = g_sfu.sfu01         #來源單號(整理日報單號)
      LET g_sfb.sfbud02 = p_sfv11              #來源造型工單
      
      CALL s_auto_assign_no("asf",g_sfb.sfb01,g_sfb.sfb81,"1","sfb_file","sfb01","","","")
           RETURNING li_result,g_sfb.sfb01
      IF (NOT li_result) THEN
         CALL s_errmsg('','','','TSD0099',1)
         LET g_success = 'N'
         EXIT WHILE
      END IF
         
      INSERT INTO sfb_file VALUES(g_sfb.*)
      IF SQLCA.sqlcode THEN
         CALL s_errmsg('sfb01',g_sfb.sfb01,'ins sfb_file:',SQLCA.sqlcode,1)
         LET g_success = 'N'
         EXIT WHILE
      END IF   
      
      #產生加工工單備料檔:依照加工料號BOM表產生(標準LIB)
      CALL t621hc_gen_sfa()
      IF g_success = 'N' THEN
         EXIT WHILE
      END IF
            
      EXIT WHILE
   END WHILE

END FUNCTION

#產生研磨工單備料檔:依照研磨料號BOM表產生(標準LIB)
FUNCTION t621hc_gen_sfa()
   DEFINE l_cnt        LIKE type_file.num5
   DEFINE l_minopseq   LIKE type_file.num5
   DEFINE l_sfa        RECORD LIKE sfa_file.*
   
   WHILE TRUE
      INITIALIZE l_sfa.* TO NULL
      
      LET l_cnt = 0 
      SELECT COUNT(*) 
        INTO l_cnt 
        FROM sfa_file
       WHERE sfa01 = g_sfb.sfb01
      IF l_cnt > 0 THEN
         CALL s_errmsg('sfb01',g_sfb.sfb01,'','asf-413',1)
         LET g_success = 'N' 
         EXIT WHILE
      END IF
      
      CALL s_minopseq(g_sfb.sfb05,g_sfb.sfb06,g_sfb.sfb071) RETURNING l_minopseq
      
      CALL s_cralc(g_sfb.sfb01,g_sfb.sfb02,g_sfb.sfb05,'Y',
                   g_sfb.sfb08,g_sfb.sfb071,'Y',g_sma.sma71,l_minopseq,g_sfb.sfb95)  
         RETURNING l_cnt
      
      UPDATE sfa_file
         SET sfa11 = 'N'
       WHERE sfa01 = g_sfb.sfb01

      IF STATUS OR SQLCA.SQLERRD[3] = 0  THEN
         LET g_success = 'N'
         EXIT WHILE
      END IF
      
      IF l_cnt = 0 THEN 
         CALL s_errmsg('sfb01',g_sfb.sfb01,'','TSD0098',1)
         LET g_success = 'N'
         EXIT WHILE
      END IF
         
      EXIT WHILE
   END WHILE
END FUNCTION

#加工發料單
FUNCTION t621hc_gen_sfp()
   DEFINE l_sfb      RECORD LIKE sfb_file.*
   DEFINE l_sfp      RECORD LIKE sfp_file.*
   DEFINE l_sfq      RECORD LIKE sfq_file.*
   DEFINE l_ta_imac03 LIKE ima_file.ta_imac03
   DEFINE li_result  LIKE type_file.num5
   
   LET g_errno = ''
   WHILE TRUE 
      INITIALIZE l_sfb.* TO NULL
      SELECT * INTO l_sfb.*
        FROM sfb_file
       WHERE sfb01 = g_sfb.sfb01
       
      #產生發料單單頭(sfp_file)
      INITIALIZE l_sfp.* TO NULL
      
      LET l_sfp.sfp01 = 'XDA'         
      LET l_sfp.sfp02  = g_sfu.sfu02
      LET l_sfp.sfp03  = g_sfu.sfu02
      LET l_sfp.sfp04  = 'N'
      LET l_sfp.sfp05  = 'N'
      LET l_sfp.sfp06  = '1'
      LET l_sfp.sfp07  = g_grup
      LET l_sfp.sfp09  ='N'
      LET l_sfp.sfpuser=g_user
      LET l_sfp.sfpgrup=g_grup
      LET l_sfp.sfpdate=TODAY
      LET l_sfp.sfpconf = 'N'
      LET l_sfp.sfpplant=g_plant
      LET l_sfp.sfplegal=g_legal
      LET l_sfp.sfporiu = g_user
      LET l_sfp.sfporig = g_grup
      LET l_sfp.sfp15 = '0'    
      LET l_sfp.sfp16 = g_user 
      LET l_sfp.sfpmksg = 'N'  
      LET l_sfp.sfpud04 = l_sfb.ta_sfb04   #來源整理日報單號
      LET l_sfp.sfpud05 = l_sfb.ta_sfb02   #生產批號
 
      CALL s_auto_assign_no("asf",l_sfp.sfp01,l_sfp.sfp02,"","sfp_file","sfp01","","","")
        RETURNING li_result,l_sfp.sfp01
      IF (NOT li_result) THEN
         CALL s_errmsg('','','','TSD0103',1)
         LET g_success = 'N'
         EXIT WHILE
      END IF
      
      INSERT INTO sfp_file VALUES (l_sfp.*)
      IF SQLCA.sqlcode THEN
         CALL s_errmsg('sfp01',l_sfp.sfp01,'ins sfp_file:', SQLCA.sqlcode,1)
         LET g_success = 'N'
         EXIT WHILE
      END IF

      #產生發料單單身(sfq_file)
      INITIALIZE l_sfq.* TO NULL 
      LET l_sfq.sfq01 = l_sfp.sfp01
      LET l_sfq.sfq02 = l_sfb.sfb01
      LET l_sfq.sfq03 = l_sfb.sfb08
      LET l_sfq.sfq04 = ' '
      LET l_sfq.sfq05 = g_sfu.sfu02
      LET l_sfq.sfq06 = NULL
      LET l_sfq.sfq08 = l_sfq.sfq03
      LET l_sfq.sfqplant=g_plant
      LET l_sfq.sfqlegal=g_legal

      INSERT INTO sfq_file VALUES (l_sfq.*)
      IF SQLCA.sqlcode THEN
         CALL s_errmsg('sfq01',l_sfp.sfp01,'ins sfq_file:', SQLCA.sqlcode,1)
         LET g_success = 'N'
         EXIT WHILE
      END IF
      
      LET part_type = 'N'  #發料前不需調撥
      LET noqty = 'N'      #以方法2 3發料，庫存不足不發料
      LET short_data = 'N' #以方法4 5發料，庫存不足不發料
      CALL t621_gen_sfs(l_sfq.*)
      IF SQLCA.sqlcode THEN
         LET g_success = 'N'
         EXIT WHILE
      END IF
      
      EXIT WHILE
   END WHILE
   
   RETURN l_sfp.sfp01
END FUNCTION

#發料單第三單身(依套數發料/退料(When sfp06=1/6))
FUNCTION t621_gen_sfs(p_sfq)
   DEFINE p_sfq        RECORD LIKE sfq_file.*
   DEFINE l_sql        STRING
   DEFINE s_u_flag     LIKE type_file.chr1
   DEFINE l_main_ware  LIKE img_file.img02
   DEFINE l_main_loc   LIKE img_file.img03
   DEFINE l_wip_ware   LIKE img_file.img02
   DEFINE l_wip_loc    LIKE img_file.img03
   
   INITIALIZE g_sfa.* TO NULL
   
   LET l_sql = "SELECT sfa_file.*,ima108 FROM sfa_file, ima_file",
               " WHERE sfa01='",p_sfq.sfq02,"'",
               "   AND sfa26 IN ('0','1','2','3','4','5','T','7','8')",
               "   AND sfa03=ima01 AND (sfa11 NOT IN ('X') OR sfa11 IS NULL)",       
               "   AND (sfa05-sfa065)>=0"   #應發-委外代買量>0 
   LET l_sql = l_sql CLIPPED," AND sfa11 <> 'S' "

   IF NOT cl_null(p_sfq.sfq04) THEN
      LET l_sql = l_sql CLIPPED,"  AND sfa08 = '",p_sfq.sfq04,"'"
   END IF
   LET l_sql = l_sql CLIPPED," ORDER BY sfa03"
   PREPARE t621hc_g_b1_pre FROM l_sql
   DECLARE t621hc_g_b1_c CURSOR FOR t621hc_g_b1_pre
  
   FOREACH t621hc_g_b1_c INTO g_sfa.*,g_ima108   #原始料件(g_sfa)
      IF part_type = 'Y' AND (g_ima108= 'N' ) THEN   
         CONTINUE FOREACH
      END IF

      IF part_type = 'N' AND (g_ima108 = 'Y' ) THEN  
         CONTINUE FOREACH
      END IF
      
      LET g_sfa.sfa05=g_sfa.sfa05-g_sfa.sfa065   #扣除委外代買量
 
      IF g_sfa.sfa26 MATCHES '[01257]' THEN
         #若是全數代買時則不允許做退料
         IF g_sfa.sfa05 = 0 THEN 
            CONTINUE FOREACH
         END IF

         LET issue_qty=(g_sfa.sfa05-g_sfa.sfa06)
         LET g_sfa2.* = g_sfa.*
         LET issue_qty1=issue_qty
         #LET l_main_ware = ' '
         LET l_main_loc  = ' '
         LET l_wip_ware  = ' '
         LET l_wip_loc   = ' '
         LET issue_type = '2'    #依指定倉儲批發料
         LET ware_no = 'CW4'     #指定倉 #加工發料一定從CW4發
         LET loc_no  = ' '       #指定儲
         LET lot_no  = ' '       #指定批
         LET l_main_ware = 'CW4'
         SELECT imd01 FROM imd_file
          WHERE imd01 = l_main_ware
         IF cl_null(l_main_ware) THEN 
            CALL s_errmsg('','',g_sfa.sfa03,'TSD0113',1)
            LET g_success = 'N'
            CONTINUE FOREACH
         END IF

         CALL t621hc_chk_img(p_sfq.*,l_main_ware,l_main_loc,l_wip_ware,l_wip_loc,lot_no,FALSE)
      
         CONTINUE FOREACH
      END IF
  
      # 當有替代狀況時, 須作以下處理:
      LET l_sql="SELECT * FROM sfa_file",
                " WHERE sfa01='",g_sfa.sfa01,"' AND sfa27='",g_sfa.sfa03,"'",
                "   AND sfa08='",g_sfa.sfa08,"' AND sfa12='",g_sfa.sfa12,"'",
                "   AND sfa012= '",g_sfa.sfa012,"' AND sfa013 = ",g_sfa.sfa013
      IF p_sfq.sfq01='6' THEN
         LET l_sql = l_sql CLIPPED," AND sfa05 > 0 "  CLIPPED
      END IF
      
      SELECT MAX(sfa26) INTO s_u_flag FROM sfa_file   # 到底是 S 或 U
       WHERE sfa01=g_sfa.sfa01 AND sfa27=g_sfa.sfa03
         AND sfa08=g_sfa.sfa08 AND sfa12=g_sfa.sfa12
         AND sfa012=g_sfa.sfa012 AND sfa013=g_sfa.sfa013   
      # U:先發取代件,再發原料件 S:先發原料件,再發替代件
      IF s_u_flag='U' OR s_u_flag = 'T' THEN
         LET l_sql=l_sql CLIPPED," ORDER BY sfa26 DESC, sfa03"
      ELSE
         LET l_sql=l_sql CLIPPED," ORDER BY sfa26     , sfa03"
      END IF
      PREPARE g_b1_p9 FROM l_sql
      DECLARE g_b1_c9 CURSOR FOR g_b1_p9
      FOREACH g_b1_c9 INTO g_sfa2.*                    #應發(含替代)料件(g_sfa2
         LET g_sfa2.sfa05=g_sfa2.sfa05-g_sfa2.sfa065   #扣除委外代買量
         LET issue_qty=issue_qty*g_sfa2.sfa28
       
         LET l_main_ware = ' '
         LET l_main_loc  = ' '
         LET l_wip_ware  = ' '
         LET l_wip_loc   = ' '
         LET issue_type = '2'    #依指定倉儲批發料
         LET ware_no = 'CW4'     #指定倉 #加工發料一定從CW4發
         LET loc_no  = ' '       #指定儲
         LET lot_no  = ' '       #指定批

         LET l_main_ware = 'CW4'
         IF cl_null(l_main_ware) THEN 
            CALL s_errmsg('','',g_sfa.sfa03,'TSD0113',1)
            LET g_success = 'N'
            CONTINUE FOREACH
         END IF

         CALL t621hc_chk_img(p_sfq.*,l_main_ware,l_main_loc,l_wip_ware,l_wip_loc,lot_no,FALSE)
        
         ## issue_qty的計算應以sfq03* sfa161來計算才不會被改變,影響後續欠料數量的計算
         IF g_sfa2.sfa05<=g_sfa2.sfa06 THEN 
            CONTINUE FOREACH 
         END IF 
         IF issue_qty<=(g_sfa2.sfa05-g_sfa2.sfa06) THEN  
            LET issue_qty1=issue_qty

            CALL t621hc_chk_img(p_sfq.*,l_main_ware,l_main_loc,l_wip_ware,l_wip_loc,lot_no,FALSE)      
            EXIT FOREACH
         ELSE
            LET issue_qty1=(g_sfa2.sfa05-g_sfa2.sfa06)  

            CALL t621hc_chk_img(p_sfq.*,l_main_ware,l_main_loc,l_wip_ware,l_wip_loc,lot_no,FALSE)      
            LET issue_qty=(issue_qty-img_qty)/g_sfa2.sfa28
         END IF
      END FOREACH
   END FOREACH   
   
END FUNCTION

FUNCTION t621hc_chk_img(p_sfq,l_main_ware,l_main_loc,l_wip_ware,l_wip_loc,l_lot_no,l_sie_flag)
   DEFINE p_sfq       RECORD LIKE sfq_file.*
   DEFINE l_sql       LIKE type_file.chr1000
   DEFINE l_img10     LIKE img_file.img10
   DEFINE l_factor    LIKE img_file.img21
   DEFINE l_cnt       LIKE type_file.num5
   DEFINE l_main_ware LIKE img_file.img02
   DEFINE l_main_loc  LIKE img_file.img03
   DEFINE l_wip_ware  LIKE img_file.img02
   DEFINE l_wip_loc   LIKE img_file.img03
   DEFINE l_lot_no    LIKE img_file.img04  
   DEFINE l_sie_flag  LIKE type_file.num5  #TRUE->依備置單產生  FALSE->不依備置產生
   DEFINE l_img09     LIKE img_file.img09
   DEFINE l_flag      LIKE type_file.num5
   DEFINE l_str       STRING

   IF cl_null(l_main_loc) THEN LET l_main_loc = ' ' END IF 
   IF cl_null(l_wip_loc)  THEN LET l_wip_loc  = ' ' END IF 
   IF cl_null(l_lot_no)   THEN LET l_lot_no   = ' ' END IF

   IF NOT cl_null(l_main_ware) THEN
      IF NOT s_chk_ware(l_main_ware) THEN  #检查仓库是否属于当前门店
         LET g_success = 'N'
         RETURN
      END IF
   END IF
   IF NOT cl_null(l_wip_ware) THEN
      IF NOT s_chk_ware(l_wip_ware) THEN  #检查仓库是否属于当前门店
         LET g_success = 'N'
         RETURN
      END IF
   END IF

   IF g_ima108 = 'Y' THEN
      LET l_main_ware = l_wip_ware
      LET l_main_loc  = l_wip_loc
   END IF
   IF cl_null(l_main_ware) THEN LET l_main_ware=ware_no END IF
   IF l_main_loc IS NULL THEN LET l_main_loc =loc_no  END IF
   IF issue_type='1' THEN
      LET g_img.img01=g_sfa2.sfa03      
      LET g_img.img02=l_main_ware
      LET g_img.img03=l_main_loc
      LET g_img.img04=l_lot_no
      LET issue_qty2=issue_qty1

      LET l_img10 = 0  
      SELECT img09,img10 INTO l_img09,l_img10 FROM img_file
       WHERE img01=g_img.img01 AND img02=g_img.img02    
         AND img03=g_img.img03 AND img04=g_img.img04
      IF cl_null(l_img10) THEN LET l_img10 = 0 END IF
      IF STATUS = 100 AND g_img.img02 <> 'CW4' THEN    
         LET g_msg4 = cl_getmsg('TSD0115',g_lang)
         IF cl_null(l_main_ware) THEN LET l_main_ware = '　' END IF
         IF cl_null(l_main_loc ) THEN LET l_main_loc  = '　' END IF
          
         LET g_msg4 = cl_replace_err_msg(g_msg4,l_main_ware||'|'||l_main_loc)
         CALL s_errmsg('','',g_sfa2.sfa03||g_msg4,'!',1)
         LET g_success = 'N'
         RETURN
      END IF

      LET l_factor=0
      CALL s_umfchk(g_img.img01,l_img09,g_sfa2.sfa12) RETURNING l_flag,l_factor
      IF l_flag=1 THEN 
         CALL s_errmsg('','',g_sfa2.sfa03,'mfg2719',1)
         LET g_success = 'N'
         RETURN 
      END IF
      LET l_img10 = l_img10*l_factor

      IF issue_qty2 <= l_img10 THEN
         CALL t621hc_ins_sfs(p_sfq.*)
      ELSE
         #主要倉/儲庫存不足，錯誤
         LET g_msg4 = cl_getmsg('TSD0115',g_lang)
         IF cl_null(l_main_ware) THEN LET l_main_ware = '　' END IF
         IF cl_null(l_main_loc ) THEN LET l_main_loc  = '　' END IF
          
         LET g_msg4 = cl_replace_err_msg(g_msg4,l_main_ware||'|'||l_main_loc)
         CALL s_errmsg('','',g_sfa2.sfa03||g_msg4,'!',1)
         LET g_success = 'N'
      END IF
      LET img_qty = issue_qty1 
      RETURN
   END IF
 
   IF issue_type MATCHES '[2]' THEN 
      LET g_img.img01=g_sfa2.sfa03      
      LET g_img.img02=ware_no
      LET g_img.img03=loc_no
      LET g_img.img04=l_lot_no 
      LET issue_qty2=issue_qty1
    
      SELECT img09,img10 INTO l_img09,l_img10 FROM img_file
       WHERE img01=g_img.img01 AND img02=g_img.img02     
         AND img03=g_img.img03 AND img04=g_img.img04
      IF STATUS = 100 AND g_img.img02 <> 'CW4' THEN    
         LET g_msg4 = cl_getmsg('TSD0114',g_lang)
         LET g_msg4 = cl_replace_err_msg(g_msg4,ware_no)
         CALL s_errmsg('','',g_sfa2.sfa03||g_msg4,'!',1)
         LET g_success = 'N'
         RETURN
      END IF
      #自動新增img
      IF cl_null(l_img10) AND g_img.img02 = 'CW4' THEN
         CALL s_add_img(g_img.img01,g_img.img02,
                        g_img.img03,g_img.img04,
                        g_sfu.sfu01,'0',   #參考序號，暫填0
                        g_sfu.sfu02)
         IF g_errno = 'N' THEN
            LET l_str = g_img.img01,'|',g_img.img02,'|',
                        g_img.img03,'|',g_img.img04
            LET g_msg = cl_getmsg('TSD0136',g_lang)
            LET g_msg = cl_replace_err_msg(g_msg,l_str)
            CALL s_errmsg('','',g_msg,'REB-131',1)
            LET g_success = 'N'
            RETURN
         END IF
         SELECT img09,img10 INTO l_img09,l_img10 FROM img_file
          WHERE img01=g_img.img01 AND img02=g_img.img02
            AND img03=g_img.img03 AND img04=g_img.img04
      END IF

      IF cl_null(l_img10) THEN LET l_img10 = 0 END IF
      LET l_factor=0
      CALL s_umfchk(g_img.img01,l_img09,g_sfa2.sfa12) RETURNING l_flag,l_factor
      IF l_flag=1 THEN 
         CALL s_errmsg('','',g_sfa2.sfa03,'mfg2719',1)
         LET g_success = 'N'
         RETURN 
      END IF

      IF issue_qty2 <= l_img10 OR g_img.img02 = 'CW4' THEN
         CALL t621hc_ins_sfs(p_sfq.*)
      ELSE
         IF g_sma.sma894[3,3]='N' OR g_sma.sma894[3,3] IS NULL THEN
            #指定倉庫的庫存不足，錯誤
            LET g_msg4 = cl_getmsg('TSD0114',g_lang)
            LET g_msg4 = cl_replace_err_msg(g_msg4,ware_no)
            CALL s_errmsg('','TSD0114',g_sfa2.sfa03||g_msg4,'!',1)
            LET g_success = 'N'
         END IF
      END IF
    
      LET img_qty = issue_qty1 
      RETURN
   END IF
 
   IF issue_type MATCHES '[3]' THEN
      LET g_img.img01=g_sfa2.sfa03
      LET g_img.img02=g_sfa2.sfa30
      LET g_img.img03=g_sfa2.sfa31
      LET g_img.img04=' '
      LET issue_qty2=issue_qty1
      IF issue_qty2 <= 0 AND noqty = 'N' THEN RETURN END IF
   
      LET l_img10 = 0  
      SELECT img09,img10 INTO l_img09,l_img10 FROM img_file
       WHERE img01=g_img.img01 AND img02=g_img.img02
         AND img03=g_img.img03 AND img04=g_img.img04
      IF cl_null(l_img10) THEN LET l_img10 = 0 END IF

      LET l_factor=0
      CALL s_umfchk(g_img.img01,l_img09,g_sfa2.sfa12) RETURNING l_flag,l_factor
      IF l_flag=1 THEN 
         CALL s_errmsg('','',g_sfa2.sfa03,'mfg2719',1)
         LET g_success = 'N'
         RETURN 
      END IF
      LET l_img10 = l_img10*l_factor

      IF issue_qty2 <= l_img10 THEN
         CALL t621hc_ins_sfs(p_sfq.*)
      ELSE
         IF noqty = 'Y' THEN
            LET g_img.img02 = cl_getmsg('asf-012',g_lang)  
            CALL t621hc_ins_sfs(p_sfq.*)
         ELSE
            RETURN
         END IF
      END IF
      
      LET img_qty = issue_qty1
      RETURN
   END IF
 
   IF issue_type MATCHES '[45]' AND ware_no IS NOT NULL THEN
      LET g_img.img01 = g_sfa2.sfa03
      LET g_img.img02 = ware_no
   END IF
 
   IF issue_type MATCHES '[45]' AND loc_no IS NOT NULL THEN
      LET g_img.img01 = g_sfa2.sfa03
      LET g_img.img03 = loc_no
   END IF
 
   IF issue_type MATCHES '[45]' AND lot_no IS NOT NULL THEN
      LET g_img.img01 = g_sfa2.sfa03
      LET g_img.img04 = lot_no
   END IF
   
   LET l_img10 = (g_sfa2.sfa05-g_sfa2.sfa06) * g_sfa2.sfa13
   LET img_qty=0
   LET l_sql="SELECT * FROM img_file",
             " WHERE img01='",g_sfa2.sfa03,"'",  #料號
             "   AND img10>0 AND img23='Y'"      #可用
   IF NOT cl_null(l_main_ware) AND issue_type = '1' THEN
      LET l_sql=l_sql CLIPPED," AND img02='",l_main_ware,"'"
   END IF
   IF NOT cl_null(l_main_loc) AND issue_type = '1' THEN
      LET l_sql=l_sql CLIPPED," AND img03='",l_main_loc,"'"
   END IF
   IF NOT cl_null(l_lot_no) AND issue_type = '1'  THEN 
      LET l_sql=l_sql CLIPPED," AND img04='",l_lot_no,"'"  
   END IF
   IF NOT cl_null(ware_no) AND issue_type MATCHES '[245]' THEN
      LET l_sql=l_sql CLIPPED," AND img02='",ware_no,"'"
   END IF
   IF NOT cl_null(loc_no) AND issue_type MATCHES '[245]' THEN
      LET l_sql=l_sql CLIPPED," AND img03='",loc_no,"'"
   END IF
   IF NOT cl_null(lot_no) AND issue_type MATCHES '[245]'  THEN  
      LET l_sql=l_sql CLIPPED," AND img04='",lot_no,"'"   
   END IF
   LET l_sql=l_sql CLIPPED," ORDER BY img27"      #發料順序
   PREPARE g_b1_p5 FROM l_sql
   DECLARE g_b1_c5 CURSOR FOR g_b1_p5
   FOREACH g_b1_c5 INTO g_img.*
      IF l_sie_flag THEN
         IF NOT cl_null(l_main_ware) THEN LET g_img.img02 = l_main_ware END IF
         IF NOT cl_null(l_main_loc)  THEN LET g_img.img03 = l_main_loc  END IF
         IF NOT cl_null(l_lot_no)    THEN LET g_img.img04 = l_lot_no    END IF       
      END IF
      
      IF STATUS THEN CALL cl_err('fore img',STATUS,1) EXIT FOREACH END IF
      IF g_sfa2.sfa12 = g_img.img09 THEN
         LET l_factor = 1
      ELSE
         CALL s_umfchk(g_img.img01,g_img.img09,g_sfa2.sfa12)
            RETURNING l_cnt,l_factor
         IF l_cnt = 1 THEN
            LET l_factor = 1
         END IF
      END IF
      LET g_img.img10 = g_img.img10 * l_factor
      IF issue_type='5' THEN      # 扣除已撿量
         SELECT SUM(sfs05) INTO qty_alo FROM sfs_file,sfp_file 
               WHERE sfs04=g_img.img01 AND sfs07=g_img.img02
                 AND sfs08=g_img.img03 AND sfs09=g_img.img04
                 AND sfp01=sfs01 AND sfpconf != 'X'
         IF qty_alo IS NULL THEN LET qty_alo = 0 END IF
         LET g_img.img10=g_img.img10-qty_alo
         IF g_img.img10<=0 THEN CONTINUE FOREACH END IF
      END IF
      #庫存量
      IF issue_qty1<=g_img.img10 THEN
         LET issue_qty2=issue_qty1
         CALL t621hc_ins_sfs(p_sfq.*)
         LET issue_qty1=issue_qty1-issue_qty2
         LET img_qty = img_qty+issue_qty2
         EXIT FOREACH
      ELSE
         LET issue_qty2=g_img.img10
         CALL t621hc_ins_sfs(p_sfq.*)
         LET issue_qty1=issue_qty1-issue_qty2
         LET img_qty = img_qty+issue_qty2
      END IF
   END FOREACH
 
   #產生一筆 Shortage 項次以供警告
   IF short_data='Y' AND issue_qty1>0 THEN   
      LET issue_qty2=issue_qty1
      LET g_img.img01=g_sfa2.sfa03
      LET g_img.img02 = cl_getmsg('asf-012',g_lang)
      LET g_img.img03=' '
      LET g_img.img04=' '
      CALL t621hc_ins_sfs(p_sfq.*)
   END IF
END FUNCTION

FUNCTION t621hc_ins_sfs(p_sfq)  #依 issue_qty2 Insert sfs_file
   DEFINE p_sfq   RECORD LIKE sfq_file.*
   DEFINE l_gfe03 LIKE gfe_file.gfe03 
   DEFINE l_tot   LIKE sfs_file.sfs05 #記錄未過賬退料數量
   DEFINE l_count LIKE type_file.num5 
   DEFINE l_sfs   RECORD LIKE sfs_file.*
   DEFINE l_sfs02 LIKE sfs_file.sfs02
 
   SELECT gfe03 INTO l_gfe03 FROM gfe_file
      WHERE gfe01=g_sfa2.sfa12
   IF SQLCA.sqlcode OR cl_null(l_gfe03) THEN
      LET l_gfe03=0
   END IF

   LET l_sfs.sfs01=p_sfq.sfq01
   SELECT MAX(sfs02) INTO l_sfs02 FROM sfs_file WHERE sfs01=p_sfq.sfq01
   IF cl_null(l_sfs02) THEN
      LET l_sfs02 = 0
   END IF
   LET l_sfs02 = l_sfs02 + 1
   LET l_sfs.sfs02=l_sfs02
   LET l_sfs.sfs03=g_sfa2.sfa01
   LET l_sfs.sfs04=g_img.img01
   LET l_sfs.sfs05=issue_qty2 
   LET l_sfs.sfs05=cl_digcut(issue_qty2,l_gfe03) 
   LET l_sfs.sfs06=g_sfa2.sfa12
   LET l_sfs.sfs07=g_img.img02
   LET l_sfs.sfs08=g_img.img03
   LET l_sfs.sfs09=g_img.img04
   LET l_sfs.sfs10=g_sfa2.sfa08
   LET l_sfs.sfs26=NULL
   LET l_sfs.sfs27=NULL
   LET l_sfs.sfs28=NULL
   LET l_sfs.sfs36=g_sfa2.sfa36
   IF g_sfa2.sfa26 MATCHES '[SUTZ]' THEN
      LET l_sfs.sfs26=g_sfa2.sfa26
      LET l_sfs.sfs27=g_sfa2.sfa27
      LET l_sfs.sfs28=g_sfa2.sfa28
   END IF
   IF l_sfs.sfs07 IS NULL THEN LET l_sfs.sfs07 = ' ' END IF
   IF l_sfs.sfs08 IS NULL THEN LET l_sfs.sfs08 = ' ' END IF
   IF l_sfs.sfs09 IS NULL THEN LET l_sfs.sfs09 = ' ' END IF
    
   LET l_sfs.sfs012 = g_sfa2.sfa012
   LET l_sfs.sfs013 = g_sfa2.sfa013

   IF cl_null(l_sfs.sfs012) THEN LET l_sfs.sfs012 = ' ' END IF 
   IF cl_null(l_sfs.sfs013) THEN LET l_sfs.sfs013 = 0   END IF  

   IF g_sma.sma115 = 'Y' THEN
      CALL t621_set_du_by_origin(l_sfs.*) RETURNING l_sfs.*
   END IF

   SELECT sfb98 INTO l_sfs.sfs930
     FROM sfb_file
    WHERE sfb01=p_sfs03
   IF cl_null(l_sfs.sfs27) THEN
      LET l_sfs.sfs27=l_sfs.sfs04
   END IF
   IF cl_null(l_sfs.sfs27) THEN
      LET l_sfs.sfs27 = ' '
   END IF
   IF cl_null(l_sfs.sfs28) THEN
      SELECT sfa28 INTO l_sfs.sfs28
        FROM sfa_file
       WHERE sfa01 = l_sfs.sfs03 
         AND sfa03 = l_sfs.sfs04
         AND sfa08 = l_sfs.sfs10
         AND sfa12 = l_sfs.sfs06
         AND sfa27 = l_sfs.sfs27
         AND sfa012= l_sfs.sfs012
         AND sfa013= l_sfs.sfs013
   END IF
 
   LET l_sfs.sfsplant = g_plant
   LET l_sfs.sfslegal = g_legal
 
   INSERT INTO sfs_file VALUES(l_sfs.*)
   IF STATUS THEN 
      CALL s_errmsg('','',' ins sfs_file: ',STATUS,1)
      LET g_success = 'N'
      RETURN
   END IF
   
END FUNCTION

FUNCTION t621_set_du_by_origin(p_sfs)
  DEFINE p_sfs      RECORD LIKE sfs_file.*
  DEFINE l_ima55    LIKE ima_file.ima55,
         l_ima31    LIKE ima_file.ima31,
         l_ima906   LIKE ima_file.ima906,
         l_ima907   LIKE ima_file.ima907,
         l_ima908   LIKE ima_file.ima908,
         l_factor   LIKE ima_file.ima31_fac
 
   SELECT ima55,ima906,ima907,ima908
     INTO l_ima55,l_ima906,l_ima907,l_ima908
     FROM ima_file WHERE ima01 = p_sfs.sfs04
 
   LET p_sfs.sfs30 = p_sfs.sfs06

   #應該是與工單備料檔中的備料單位轉換
   CALL s_umfchk(p_sfs.sfs04,p_sfs.sfs06,g_sfa2.sfa12)
         RETURNING g_errno,l_factor
   LET p_sfs.sfs31 = l_factor
   LET p_sfs.sfs32 = p_sfs.sfs05 / l_factor
 
   IF l_ima906 = '1' THEN  #不使用雙單位
      LET p_sfs.sfs33 = NULL
      LET p_sfs.sfs34 = NULL
      LET p_sfs.sfs35 = NULL
   ELSE
      LET p_sfs.sfs33 = l_ima907
      #應該是與工單備料檔中的備料單位轉換
      CALL s_umfchk(p_sfs.sfs04,p_sfs.sfs33,g_sfa2.sfa12)
           RETURNING g_errno,l_factor
      LET p_sfs.sfs34 = l_factor
      IF l_ima906 = '3' THEN 
         LET p_sfs.sfs35 = p_sfs.sfs32 / l_factor
      ELSE
         LET p_sfs.sfs35 = 0
      END IF
   END IF

   RETURN p_sfs.*
END FUNCTION

#初始化變數
FUNCTION t621hc_sfb_init()

   INITIALIZE g_sfb.* TO NULL
   
   LET g_sfb.sfb02  ='1'            #工單型態
   LET g_sfb.sfb04  ='1'            #工單狀態
   LET g_sfb.sfb07  = NULL          #BOM版本
   LET g_sfb.sfb071 = g_sfu.sfu02
   LET g_sfb.sfb081 =0
   LET g_sfb.sfb09  =0
   LET g_sfb.sfb10  =0
   LET g_sfb.sfb11  =0
   LET g_sfb.sfb111 =0
   LET g_sfb.sfb12  =0
   LET g_sfb.sfb121 =0
   LET g_sfb.sfb13  = g_sfu.sfu02
   LET g_sfb.sfb14 = "00:00"
   LET g_sfb.sfb15  = g_sfu.sfu02
   LET g_sfb.sfb16 = "00:00"
   LET g_sfb.sfb23  ='N'
   LET g_sfb.sfb24  ='N'
   LET g_sfb.sfb251 = g_sfb.sfb13
   LET g_sfb.sfb29  ='Y'
   LET g_sfb.sfb39  ='1'
   LET g_sfb.sfb41  ='N'
   LET g_sfb.sfb81  = g_sfu.sfu02
   LET g_sfb.sfb87  ='N'
   LET g_sfb.sfb93 = 'N'
   LET g_sfb.sfb94 = 'N'
   LET g_sfb.sfb99  ='N'
   LET g_sfb.sfb1002 = 'N'
   LET g_sfb.sfbacti= 'Y'
   LET g_sfb.sfbuser= g_user
   LET g_sfb.sfbgrup= g_grup
   LET g_sfb.sfbdate= TODAY
   LET g_data_plant = g_plant
   LET g_sfb.sfb1002='N'
   LET g_sfb.sfb43 = '0'
   LET g_sfb.sfb44 = 'tiptop'  #一律填入tiptop，避免登入帳不存在員工編號
   LET g_sfb.sfbmksg = 'N'
   LET g_sfb.sfbplant = g_plant
   LET g_sfb.sfblegal = g_legal
   LET g_sfb.sfboriu = g_user
   LET g_sfb.sfborig = g_grup
   LET g_sfb.sfb104 = 'N'
   LET g_sfb.sfb82 = g_grup
   LET g_sfb.sfb95 = ' '       #特性代碼
END FUNCTION

#180731 BY CMP.Geoffrey Add (E)
#180805 BY CMP.Geoffrey Add (S)
{
FUNCTION t621hc_undo_sfu_csfi301()
   DEFINE l_sql           STRING
   DEFINE l_tc_scd06      LIKE tc_scd_file.tc_scd06     #項次
   DEFINE l_tc_scd07      LIKE tc_scd_file.tc_scd07     #品號
   DEFINE l_tc_scd09      LIKE tc_scd_file.tc_scd09     #生產批號
   DEFINE l_tc_scd10_sum  LIKE tc_scd_file.tc_scd10     #完成數量(PCS)
   DEFINE l_tc_scd24_sum  LIKE tc_scd_file.tc_scd24     #不良品數
   DEFINE l_tc_scd25      LIKE tc_scd_file.tc_scd25     #工單號碼
   DEFINE l_sfu01         LIKE sfu_file.sfu01
   DEFINE l_sfp01         LIKE sfp_file.sfp01
   DEFINE l_gui_type      LIKE type_file.chr1 
   DEFINE l_bgjob         LIKE type_file.chr1 
   DEFINE l_bgerr         LIKE type_file.chr1 
   DEFINE l_prog          LIKE type_file.chr10
   DEFINE l_sfp           RECORD LIKE sfp_file.*
   DEFINE l_sfb01         LIKE sfb_file.sfb01
   DEFINE l_sfb09         LIKE sfb_file.sfb09
   DEFINE l_sfb12         LIKE sfb_file.sfb12

   IF cl_null(g_tc_scc.tc_scc01) THEN
      CALL cl_err("",-400,0)
      RETURN
   END IF

   LET g_errno = ''

   SELECT * 
     INTO g_tc_scc.* 
     FROM tc_scc_file
    WHERE tc_scc01 = g_tc_scc.tc_scc01  
      AND tc_scc02 = g_tc_scc.tc_scc02 
      AND tc_scc03 = g_tc_scc.tc_scc03 
	   AND tc_scc04 = g_tc_scc.tc_scc04 
	   AND tc_scc05 = g_tc_scc.tc_scc05 

   IF g_tc_scc.tc_sccconf = 'X' THEN
      CALL cl_err('','9024',1)       #此筆資料已作廢
      RETURN
   END IF
   
   IF g_tc_scc.tc_sccpost = 'N' THEN
      CALL cl_err('','CMP0214',1)    #沒有入庫/不良品單,不可還原,請查核!
      RETURN
   END IF 
   
   LET l_sfu01 = ''
   SELECT sfu01
     INTO l_sfu01
     FROM sfu_file
    WHERE sfuud04 = g_tc_scc.tc_scc01
      AND sfuconf = 'Y'
      AND sfupost = 'Y'
   IF cl_null(l_sfu01) THEN
      CALL cl_err('','CMP0217',1)    #此整理日報對應的造型入庫單不存在,不可還原!
      RETURN
   END IF
   
   IF NOT cl_confirm('CMP0215') THEN   #是否確認還原入庫/不良品單(Y/N)?
      RETURN 
   END IF
   
   CALL s_showmsg_init() 
   LET g_data_cnt=0
   BEGIN WORK
   LET g_success = 'Y'
   LET g_totsuccess ='Y' 
   
   LET l_gui_type = g_gui_type 
   LET l_bgjob = g_bgjob
   LET l_bgerr = g_bgerr
   LET l_prog  = g_prog
         
   LET g_gui_type = 0
   LET g_bgjob = 'Y'
   LET g_bgerr = TRUE
   LET gi_err_code = ''
   
   OPEN t6802_cl USING g_tc_scc.tc_scc01,g_tc_scc.tc_scc02,g_tc_scc.tc_scc03,g_tc_scc.tc_scc04,g_tc_scc.tc_scc05
      
   IF STATUS THEN
      CALL cl_err("OPEN t6802_cl:", STATUS, 1)
      CLOSE t6802_cl
      ROLLBACK WORK
      RETURN
   END IF
   
   FETCH t6802_cl INTO g_tc_scc.*                  # 鎖住將被更改或取消的資料
   IF SQLCA.sqlcode THEN
      CALL cl_err(g_tc_scc.tc_scc01,SQLCA.sqlcode,0)   # 資料被他人LOCK
      CLOSE t6802_cl
      ROLLBACK WORK
      RETURN
   END IF
   
   #檢查有此整理日報單號的任何一張研磨工單是否已有入庫數量/報廢數量,有則不可還原
   LET l_sql = " SELECT sfb01,sfb09,sfb12 ",
               "   FROM sfb_file ",
               "  WHERE ta_sfb04 = '",g_tc_scc.tc_scc01,"'",
               "    AND sfb87 = 'Y' "
   PREPARE t6802_sel_tc_sfb_p FROM l_sql
   DECLARE t6802_sel_tc_sfb_cs CURSOR FOR t6802_sel_tc_sfb_p
   
   #依照料號+工單+生產批號分群 還原研磨發料單/工單(同產生單子順序)
   LET l_sql = "SELECT tc_scd07,tc_scd25,tc_scd09,SUM(tc_scd10) ",
               "  FROM tc_scd_file ",
               " WHERE tc_scd01 = ? ",
               "   AND tc_scd02 = ? ",
               "   AND tc_scd03 = ? ",
               "   AND tc_scd04 = ? ",
               "   AND tc_scd05 = ? ",
               " GROUP BY tc_scd07,tc_scd25,tc_scd09 "
   PREPARE t6802_sel_tc_scd_p3 FROM l_sql
   DECLARE t6802_sel_tc_scd_cs3 CURSOR FOR t6802_sel_tc_scd_p3

   WHILE TRUE 
      LET l_sfb01 = ''
      LET l_sfb09 = 0
      LET l_sfb12 = 0
      FOREACH t6802_sel_tc_sfb_cs INTO l_sfb01,l_sfb09,l_sfb12
         IF SQLCA.sqlcode THEN
             CALL cl_err('foreach:',SQLCA.sqlcode,1)
             EXIT FOREACH
          END IF
          
         IF g_success = 'N' THEN
            LET g_totsuccess ='N' 
            LET g_success ='Y' 
         END IF
         
         IF l_sfb09 <> 0 OR l_sfb12 <> 0 THEN
            CALL s_errmsg('sfb01,sfb09,sfb12',l_sfb01||'/'||l_sfb09||'/'||l_sfb12,'','CMP0216',1)  #此研磨工單已有入庫量或報廢量,不可還原!
            LET g_success = 'N' 
         END IF

      END FOREACH
      IF g_totsuccess = 'N' THEN
         LET g_success ='N' 
         EXIT WHILE
      END IF
      
      LET l_tc_scd07 = ''
      LET l_tc_scd25 = ''
      LET l_tc_scd09 = ''
      LET l_tc_scd10_sum = ''
      FOREACH t6802_sel_tc_scd_cs3 USING g_tc_scc.tc_scc01,g_tc_scc.tc_scc02,g_tc_scc.tc_scc03,g_tc_scc.tc_scc04,g_tc_scc.tc_scc05
                                   INTO l_tc_scd07,l_tc_scd25,l_tc_scd09,l_tc_scd10_sum
         IF SQLCA.sqlcode THEN
            CALL s_errmsg('','','t6802_sel_tc_scd_cs3(foreach):',SQLCA.sqlcode,1) 
            LET g_success = 'N'
            EXIT FOREACH
         END IF
         
         #依照整理日報單身條件撈取對應的發料單/工單做還原
         LET l_sfp01 = ''
         LET l_sfb01 = ''
       #170905 By CMP.Seiman ------(S)
       IF l_tc_scd09 IS NULL THEN
         SELECT sfp01,sfq02
           INTO l_sfp01,l_sfb01
           FROM sfp_file,sfq_file
          WHERE sfp01 = sfq01 
            AND sfpud04 = g_tc_scc.tc_scc01
            AND sfpconf = 'Y'
            AND sfp04 = 'Y'
       ELSE
       #170905 By CMP.Seiman ------(E)
         SELECT sfp01,sfq02
           INTO l_sfp01,l_sfb01
           FROM sfp_file,sfq_file
          WHERE sfp01 = sfq01 
            AND sfpud04 = g_tc_scc.tc_scc01
            AND sfpud05 = l_tc_scd09
            AND sfpconf = 'Y'
            AND sfp04 = 'Y'
       END IF   #170905 By CMP.Seiman add
         IF cl_null(l_sfp01) THEN
            LET g_success = 'N'
            CALL s_errmsg('tc_scd01,tc_scd09',g_tc_scc.tc_scc01||'/'||l_tc_scd09,'','CMP0218',1)  #此整理日報對應的研磨發料單不存在,不可還原!
            EXIT FOREACH
         END IF
         IF cl_null(l_sfb01) THEN
            LET g_success = 'N'
            CALL s_errmsg('tc_scd01,tc_scd09',g_tc_scc.tc_scc01||'/'||l_tc_scd09,'','CMP0219',1)  #此整理日報對應的研磨工單不存在,不可還原!
            EXIT FOREACH
         END IF
         
         #研磨發料單 過帳還原
         LET g_prog = 'asfi511'
         CALL i501sub_z('1',l_sfp01,'',FALSE)
         IF g_success = 'N' THEN 
            CALL s_errmsg('sfp01',l_sfp01,'','TSD0165',1)
            EXIT FOREACH
         END IF
         
         #研磨發料單 取消確認
         CALL i501sub_w(l_sfp01,'',FALSE)
         IF g_success = 'N' THEN 
            CALL s_errmsg('sfp01',l_sfp01,'','TSD0166',1)
            EXIT FOREACH
         END IF

         #研磨發料單 作廢
         CALL i501sub_x(l_sfp01,'',FALSE)
         IF g_success = 'N' THEN 
            CALL s_errmsg('sfp01',l_sfp01,'','TSD0167',1)
            EXIT FOREACH
         END IF

         #研磨工單 取消確認
         LET g_prog = 'csfi301'
         CALL i301sub_firm2(l_sfb01,TRUE,'N')
         IF g_success = 'N' THEN 
            CALL s_errmsg('sfb01',l_sfb01,'','TSD0168',1)
            EXIT FOREACH
         END IF 
         
         #研磨工單 作廢
         LET g_action_choice = "void" 
         CALL i301sub_x(l_sfb01,TRUE,'N')
         IF g_success = 'N' THEN 
            CALL s_errmsg('sfb01',l_sfb01,'','TSD0168',1)
            EXIT FOREACH
         END IF  

      END FOREACH
      IF g_success = 'N' THEN 
         EXIT WHILE
      END IF

      #造型入庫單  過帳還原
      LET g_prog = 'asft620'
      CALL t620sub_w(l_sfu01,'',TRUE,'1')
      IF g_success = 'N' THEN 
         CALL s_errmsg('sfu01',l_sfu01,'','TSD0162',1)
         EXIT WHILE
      END IF

      #造型入庫單 取消確認 
      CALL t620sub_z(l_sfu01,'',TRUE)
      IF g_success = 'N' THEN 
         CALL s_errmsg('sfu01',l_sfu01,'','TSD0163',1)
         EXIT WHILE
      END IF

      #造型入庫單 作廢
      CALL t620sub_x(l_sfu01,'1',FALSE,TRUE)
      IF g_success = 'N' THEN 
         CALL s_errmsg('sfu01',l_sfu01,'','TSD0164',1)
         EXIT WHILE
      END IF

      #刪除不良品單(此整理日報單號上有的料號+日期對應到的不良日報資料都要刪除)不管確認還未確認,但是要未過帳,有過帳代表前面有報廢數量了
      DELETE FROM tc_chl_file 
       WHERE tc_chl00 = '3' 
         AND tc_chlpost = 'N' 
         AND EXISTS (SELECT 1 FROM tc_scd_file 
                      WHERE tc_scd01 = g_tc_scc.tc_scc01 
                        AND tc_scd02 = g_tc_scc.tc_scc02 
                        AND tc_scd03 = g_tc_scc.tc_scc03  
                        AND tc_scd04 = g_tc_scc.tc_scc04 
                        AND tc_scd05 = g_tc_scc.tc_scc05
                        AND tc_scd24 IS NOT NULL      #有不良數量
                        AND tc_scd07 = tc_chl03       #料號
                        AND tc_scd02 = tc_chl02  )    #日期
      IF SQLCA.sqlcode THEN  
         CALL s_errmsg('不良日報','','del tc_chl_file',SQLCA.sqlcode,1)  
         LET g_success = 'N' 
         EXIT WHILE
      END IF
      
      #更新整理日報過帳碼
      UPDATE tc_scc_file SET tc_sccpost='N',
                             tc_sccmodu = g_user,
                             tc_sccdate = g_today
       WHERE tc_scc01 = g_tc_scc.tc_scc01
         AND tc_scc02 = g_tc_scc.tc_scc02
         AND tc_scc03 = g_tc_scc.tc_scc03
	   	AND tc_scc04 = g_tc_scc.tc_scc04
	   	AND tc_scc05 = g_tc_scc.tc_scc05
      IF SQLCA.sqlcode OR SQLCA.sqlerrd[3]=0 THEN
         IF SQLCA.sqlcode = 0 THEN
            LET SQLCA.sqlcode = 9050
         END IF
         CALL cl_err3("upd","tc_scc_file",g_tc_scc.tc_scc01,"",SQLCA.sqlcode,"","upd tc_sccpost",1)
         LET g_success='N'
         EXIT WHILE
      END IF

      LET g_data_cnt=g_data_cnt+1
       
      EXIT WHILE
   END WHILE
    
   LET g_gui_type = l_gui_type
   LET g_bgjob = l_bgjob 
   LET g_bgerr = l_bgerr 
   LET g_prog = l_prog 
   
   #無符合條件時
   IF g_data_cnt = 0 AND g_success = 'Y' THEN
      CALL s_errmsg('','','','mfg3160',1)
      LET g_success = "N"
   END IF
   
   IF g_success = 'Y' THEN
      COMMIT WORK
      CALL s_errmsg('tc_scc01',g_tc_scc.tc_scc01,'','mfg1605',2)   #還原成功!
   ELSE
      ROLLBACK WORK
   END IF

   CLOSE t6802_cl
   CALL s_showmsg()

   CALL t6802_show()

END FUNCTION
}
#180805 BY CMP.Geoffrey Add (E)
