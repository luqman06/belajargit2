CREATE OR REPLACE FUNCTION public.ta_generate_shift(p_pinstance_id character varying)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO '$user', 'public'
AS $function$ DECLARE  
/*************************************************************************
* Contributor(s):  Luqman 
* function : subcon delivery
************************************************************************/
  -- Logistice
  v_ResultStr VARCHAR(2000):=''; --OBTG:VARCHAR2--
  v_Message VARCHAR(2000):=''; --OBTG:VARCHAR2--
  v_Result NUMERIC:=1; -- 0=failure
  v_Record_ID VARCHAR(32); --OBTG:VARCHAR2--
  v_User_ID VARCHAR(32):='0'; --OBTG:VARCHAR2--
  v_Org_ID VARCHAR(32); --OBTG:VARCHAR2--
  v_Client_ID VARCHAR(32); --OBTG:VARCHAR2--
  v_DocStatus VARCHAR(32);
	v_validfrom timestamp;
	v_validto timestamp;
	v_isactive bpchar;
	v_em_hris_validto timestamp;
	v_count_record numeric;
	v_shift_c_bpartner_id varchar(32);
	v_ta_shift_id_1 varchar(32);
	v_name_shift varchar(100);
	v_double_shift numeric;
	v_count_day_shift interval;
  --  Parameter
  --TYPE RECORD IS REFCURSOR;
    Cur_Parameter RECORD;
    cur_ta_c_bp_shift record;
 

   
  BEGIN
    RAISE NOTICE '%','Updating PInstance - Processing ' || p_PInstance_ID ;
    v_ResultStr:='PInstanceNotFound';
    PERFORM AD_UPDATE_PINSTANCE(p_PInstance_ID, NULL, 'Y', NULL, NULL) ;
  BEGIN --BODY
    -- Get Parameters, berfungsi untuk membaca record pada window yang aktif
    v_ResultStr:='ReadingParameters';
    FOR Cur_Parameter IN
      (SELECT i.Record_ID, i.ad_client_id, i.ad_org_id, i.AD_User_ID, p.ParameterName, p.P_String, p.P_Number, p.P_Date
      FROM AD_PInstance i
      LEFT JOIN AD_PInstance_Para p
        ON i.AD_PInstance_ID = p.AD_PInstance_ID
      WHERE i.AD_PInstance_ID = p_PInstance_ID
      ORDER BY p.SeqNo
      )
    LOOP
      v_Record_ID := Cur_Parameter.Record_ID; --movement_id
      v_User_ID := Cur_Parameter.AD_User_ID;
	  v_Org_ID := Cur_Parameter.ad_org_id;
      v_Client_ID := Cur_Parameter.ad_client_id;
    END LOOP; -- Get Parameter
--Diatas penting
       raise notice '%', 'jalan';
--    loop ta_c_bp_shift

    for cur_ta_c_bp_shift in
    (
--    		    
--    			select DISTINCT tcbs.c_bpartner_id , tcbs.ta_c_bp_shift_id ,tcbs.ta_shift_id , tcbs.validfrom , tcbs.validto, cb.isactive , cb.em_hris_validto,tcbs.issale,
--    			cb.name,(tcbs.validto::timestamp - tcbs.validfrom::timestamp) as count_day
--			    from ta_c_bp_shift tcbs 
--			    left join c_bpartner cb 
--			    on tcbs.c_bpartner_id = cb.c_bpartner_id
--			    where tcbs.ad_client_id = v_Client_ID
--			    and cb.isactive = 'Y'
--			    ORDER BY validto desc

      
    			select DISTINCT tcbs.c_bpartner_id , tcbs.ta_c_bp_shift_id ,tcbs.ta_shift_id , tcbs.validfrom , tcbs.validto, cb.isactive , cb.em_hris_validto,tcbs.issale,
    			cb.name,(tcbs.validto::timestamp - tcbs.validfrom::timestamp) as count_day
			    from (select distinct * from ta_c_bp_shift) tcbs 
			    left join c_bpartner cb 
			    on  cb.c_bpartner_id = tcbs.c_bpartner_id
			    where tcbs.ad_client_id = v_Client_ID
			    and cb.isactive = 'Y'
			    ORDER BY validto desc
	
    )
    loop

--       Bloking bila validto koskng di empolee information
      	 if (cur_ta_c_bp_shift.em_hris_validto is null ) then
			raise exception '%', cur_ta_c_bp_shift.name ||' Valid To Date Masih kosong !!!' ;
		else
		
       
--    get count record shift   
		SELECT COUNT(c_bpartner_id)
		into v_count_record
		from ta_c_bp_shift
    	where c_bpartner_id =cur_ta_c_bp_shift.c_bpartner_id ;
   
--	  bloking jika record shift kurang dari 2
	 	if (v_count_record < 2) then
			raise exception '%', 'Jumlah record yang di buat kurang dari 2' ||cur_ta_c_bp_shift.name || ' - ' || v_count_record;
	  	end if;
	 
		 
		 select count(ta_c_bp_shift_id ) ,c_bpartner_id
		 into v_double_shift
		 from ta_c_bp_shift
		 where c_bpartner_id = cur_ta_c_bp_shift.c_bpartner_id
		 group by c_bpartner_id , ta_shift_id ,date_part('month',validfrom)
		 order by count(ta_c_bp_shift_id ) desc
		 limit 1;
	
--	  bloking jika shift memliki shift yang sam dua kali brtururt turut
--		 if ( v_double_shift > 1 and cur_ta_c_bp_shift.issale = 'N') then
--		 	raise exception '%', cur_ta_c_bp_shift.name || ' - Memilik Shift sama selama dua pekan di dalam bulan yang sama !!!' ;
--		 end if;
--		 	
	--	 get jumlah dia kerja
		 if(cur_ta_c_bp_shift.count_day<interval '13  day') then
			 v_count_day_shift := cur_ta_c_bp_shift.count_day + (interval '14  day' - cur_ta_c_bp_shift.count_day);
--			 raise exception '%', ' Kurang dari 13'||v_count_day_shift ;
		 else
		 	v_count_day_shift := cur_ta_c_bp_shift.count_day + interval '1 days';
	--	 raise exception '%', ' hari Lebih dari 13'|| cur_ta_c_bp_shift.count_day  ;
		 end if;
		
	-- ambil shift sebelunya
		select ta_shift_id 
		into v_ta_shift_id_1
		from ta_c_bp_shift
		where c_bpartner_id = cur_ta_c_bp_shift.c_bpartner_id
		and ta_c_bp_shift_id != cur_ta_c_bp_shift.ta_c_bp_shift_id
		order by validto desc 
		limit 1;
	
	if (cur_ta_c_bp_shift.issale = 'N') then
		
		insert into ta_c_bp_shift (ta_c_bp_shift_id ,
		ad_client_id,
		ad_org_id,
   		created,
   		createdby,
   		updated,
   		updatedby,
   		isactive,
   		c_bpartner_id,
   		ta_shift_id ,
   		validfrom ,
   		validto,
   		issale)
   		values( get_uuid(),
   		v_Client_ID,
	    v_Org_ID,
	    now(),
	    v_User_ID,
	    now(),
	    v_User_ID,
	    'Y',
	    cur_ta_c_bp_shift.c_bpartner_id,
	    v_ta_shift_id_1,
	    cur_ta_c_bp_shift.validto + interval '1 days',
	    cur_ta_c_bp_shift.validto + v_count_day_shift,
	   'N');
	  
	  elseif (cur_ta_c_bp_shift.issale = 'Y') then
	  	insert into ta_c_bp_shift (ta_c_bp_shift_id ,
		ad_client_id,
		ad_org_id,
   		created,
   		createdby,
   		updated,
   		updatedby,
   		isactive,
   		c_bpartner_id,
   		ta_shift_id ,
   		validfrom ,
   		validto,
   		issale)
   		values( get_uuid(),
   		v_Client_ID,
	    v_Org_ID,
	    now(),
	    v_User_ID,
	    now(),
	    v_User_ID,
	    'Y',
	    cur_ta_c_bp_shift.c_bpartner_id,
	    v_ta_shift_id_1,
	    cur_ta_c_bp_shift.validto + interval '1 days',
	    cur_ta_c_bp_shift.validto + v_count_day_shift,
	   'Y');
	  
	end if;  
   end if;
    end loop;

  
	v_Result := 1;  --success
	v_Message :=  'Create Success !!!';

	
  END; --BODY
  
  IF(p_PInstance_ID IS NOT NULL) THEN
    PERFORM AD_UPDATE_PINSTANCE(p_PInstance_ID, v_User_ID, 'N', v_Result, v_Message) ;
  END IF;
 
EXCEPTION
WHEN OTHERS THEN
  v_ResultStr:= '@ERROR=' || SQLERRM;
  RAISE NOTICE '(ta_generate_shift) %', v_ResultStr;
  -- ROLLBACK;
  PERFORM AD_UPDATE_PINSTANCE(p_PInstance_ID, v_User_ID, 'N', 0, v_ResultStr);
--	RAISE EXCEPTION '(ta_generate_shift) %' , SQLERRM; 
--  RETURN;
END ;$function$
;



CREATE OR REPLACE FUNCTION public.ta_generate_shift(p_pinstance_id character varying)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO '$user', 'public'
AS $function$ DECLARE  
/*************************************************************************
* Contributor(s):  Luqman 
* function : subcon delivery
************************************************************************/
  -- Logistice
  v_ResultStr VARCHAR(2000):=''; --OBTG:VARCHAR2--
  v_Message VARCHAR(2000):=''; --OBTG:VARCHAR2--
  v_Result NUMERIC:=1; -- 0=failure
  v_Record_ID VARCHAR(32); --OBTG:VARCHAR2--
  v_User_ID VARCHAR(32):='0'; --OBTG:VARCHAR2--
  v_Org_ID VARCHAR(32); --OBTG:VARCHAR2--
  v_Client_ID VARCHAR(32); --OBTG:VARCHAR2--
  v_DocStatus VARCHAR(32);
	v_validfrom timestamp;
	v_validto timestamp;
	v_isactive bpchar;
	v_em_hris_validto timestamp;
	v_count_record numeric;
	v_shift_c_bpartner_id varchar(32);
	v_ta_shift_id_1 varchar(32);
	v_name_shift varchar(100);
	v_double_shift numeric;
	v_count_day_shift interval;
  --  Parameter
  --TYPE RECORD IS REFCURSOR;
    Cur_Parameter RECORD;
    cur_ta_c_bp_shift record;
 

   
  BEGIN
    RAISE NOTICE '%','Updating PInstance - Processing ' || p_PInstance_ID ;
    v_ResultStr:='PInstanceNotFound';
    PERFORM AD_UPDATE_PINSTANCE(p_PInstance_ID, NULL, 'Y', NULL, NULL) ;
  BEGIN --BODY
    -- Get Parameters, berfungsi untuk membaca record pada window yang aktif
    v_ResultStr:='ReadingParameters';
    FOR Cur_Parameter IN
      (SELECT i.Record_ID, i.ad_client_id, i.ad_org_id, i.AD_User_ID, p.ParameterName, p.P_String, p.P_Number, p.P_Date
      FROM AD_PInstance i
      LEFT JOIN AD_PInstance_Para p
        ON i.AD_PInstance_ID = p.AD_PInstance_ID
      WHERE i.AD_PInstance_ID = p_PInstance_ID
      ORDER BY p.SeqNo
      )
    LOOP
      v_Record_ID := Cur_Parameter.Record_ID; --movement_id
      v_User_ID := Cur_Parameter.AD_User_ID;
	  v_Org_ID := Cur_Parameter.ad_org_id;
      v_Client_ID := Cur_Parameter.ad_client_id;
    END LOOP; -- Get Parameter
--Diatas penting
       raise notice '%', 'jalan';
--    loop ta_c_bp_shift

    for cur_ta_c_bp_shift in
    (
--    		    
--    			select DISTINCT tcbs.c_bpartner_id , tcbs.ta_c_bp_shift_id ,tcbs.ta_shift_id , tcbs.validfrom , tcbs.validto, cb.isactive , cb.em_hris_validto,tcbs.issale,
--    			cb.name,(tcbs.validto::timestamp - tcbs.validfrom::timestamp) as count_day
--			    from ta_c_bp_shift tcbs 
--			    left join c_bpartner cb 
--			    on tcbs.c_bpartner_id = cb.c_bpartner_id
--			    where tcbs.ad_client_id = v_Client_ID
--			    and cb.isactive = 'Y'
--			    ORDER BY validto desc

      
    			select DISTINCT tcbs.c_bpartner_id , tcbs.ta_c_bp_shift_id ,tcbs.ta_shift_id , tcbs.validfrom , tcbs.validto, cb.isactive , cb.em_hris_validto,tcbs.issale,
    			cb.name,(tcbs.validto::timestamp - tcbs.validfrom::timestamp) as count_day
			    from (select distinct * from ta_c_bp_shift) tcbs 
			    left join c_bpartner cb 
			    on  cb.c_bpartner_id = tcbs.c_bpartner_id
			    where tcbs.ad_client_id = v_Client_ID
			    and cb.isactive = 'Y'
			    ORDER BY validto desc
	
    )
    loop

--       Bloking bila validto koskng di empolee information
      	 if (cur_ta_c_bp_shift.em_hris_validto is null ) then
			raise exception '%', cur_ta_c_bp_shift.name ||' Valid To Date Masih kosong !!!' ;
		else
		
       
--    get count record shift   
		SELECT COUNT(c_bpartner_id)
		into v_count_record
		from ta_c_bp_shift
    	where c_bpartner_id =cur_ta_c_bp_shift.c_bpartner_id ;
   
--	  bloking jika record shift kurang dari 2
	 	if (v_count_record < 2) then
			raise exception '%', 'Jumlah record yang di buat kurang dari 2' ||cur_ta_c_bp_shift.name || ' - ' || v_count_record;
	  	end if;
	 
		 
		 select count(ta_c_bp_shift_id ) ,c_bpartner_id
		 into v_double_shift
		 from ta_c_bp_shift
		 where c_bpartner_id = cur_ta_c_bp_shift.c_bpartner_id
		 group by c_bpartner_id , ta_shift_id ,date_part('month',validfrom)
		 order by count(ta_c_bp_shift_id ) desc
		 limit 1;
	
--	  bloking jika shift memliki shift yang sam dua kali brtururt turut
--		 if ( v_double_shift > 1 and cur_ta_c_bp_shift.issale = 'N') then
--		 	raise exception '%', cur_ta_c_bp_shift.name || ' - Memilik Shift sama selama dua pekan di dalam bulan yang sama !!!' ;
--		 end if;
--		 	
	--	 get jumlah dia kerja
		 if(cur_ta_c_bp_shift.count_day<interval '13  day') then
			 v_count_day_shift := cur_ta_c_bp_shift.count_day + (interval '14  day' - cur_ta_c_bp_shift.count_day);
--			 raise exception '%', ' Kurang dari 13'||v_count_day_shift ;
		 else
		 	v_count_day_shift := cur_ta_c_bp_shift.count_day + interval '1 days';
	--	 raise exception '%', ' hari Lebih dari 13'|| cur_ta_c_bp_shift.count_day  ;
		 end if;
		
	-- ambil shift sebelunya
		select ta_shift_id 
		into v_ta_shift_id_1
		from ta_c_bp_shift
		where c_bpartner_id = cur_ta_c_bp_shift.c_bpartner_id
		and ta_c_bp_shift_id != cur_ta_c_bp_shift.ta_c_bp_shift_id
		order by validto desc 
		limit 1;
	
	if (cur_ta_c_bp_shift.issale = 'N') then
		
		insert into ta_c_bp_shift (ta_c_bp_shift_id ,
		ad_client_id,
		ad_org_id,
   		created,
   		createdby,
   		updated,
   		updatedby,
   		isactive,
   		c_bpartner_id,
   		ta_shift_id ,
   		validfrom ,
   		validto,
   		issale)
   		values( get_uuid(),
   		v_Client_ID,
	    v_Org_ID,
	    now(),
	    v_User_ID,
	    now(),
	    v_User_ID,
	    'Y',
	    cur_ta_c_bp_shift.c_bpartner_id,
	    v_ta_shift_id_1,
	    cur_ta_c_bp_shift.validto + interval '1 days',
	    cur_ta_c_bp_shift.validto + v_count_day_shift,
	   'N');
	  
	  elseif (cur_ta_c_bp_shift.issale = 'Y') then
	  	insert into ta_c_bp_shift (ta_c_bp_shift_id ,
		ad_client_id,
		ad_org_id,
   		created,
   		createdby,
   		updated,
   		updatedby,
   		isactive,
   		c_bpartner_id,
   		ta_shift_id ,
   		validfrom ,
   		validto,
   		issale)
   		values( get_uuid(),
   		v_Client_ID,
	    v_Org_ID,
	    now(),
	    v_User_ID,
	    now(),
	    v_User_ID,
	    'Y',
	    cur_ta_c_bp_shift.c_bpartner_id,
	    v_ta_shift_id_1,
	    cur_ta_c_bp_shift.validto + interval '1 days',
	    cur_ta_c_bp_shift.validto + v_count_day_shift,
	   'Y');
	  
	end if;  
   end if;
    end loop;

  
	v_Result := 1;  --success
	v_Message :=  'Create Success !!!';

	
  END; --BODY
  
  IF(p_PInstance_ID IS NOT NULL) THEN
    PERFORM AD_UPDATE_PINSTANCE(p_PInstance_ID, v_User_ID, 'N', v_Result, v_Message) ;
  END IF;
 
EXCEPTION
WHEN OTHERS THEN
  v_ResultStr:= '@ERROR=' || SQLERRM;
  RAISE NOTICE '(ta_generate_shift) %', v_ResultStr;
  -- ROLLBACK;
  PERFORM AD_UPDATE_PINSTANCE(p_PInstance_ID, v_User_ID, 'N', 0, v_ResultStr);
--	RAISE EXCEPTION '(ta_generate_shift) %' , SQLERRM; 
--  RETURN;
END ;$function$
;



CREATE OR REPLACE FUNCTION public.ta_generate_shift(p_pinstance_id character varying)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO '$user', 'public'
AS $function$ DECLARE  
/*************************************************************************
* Contributor(s):  Luqman 
* function : subcon delivery
************************************************************************/
  -- Logistice
  v_ResultStr VARCHAR(2000):=''; --OBTG:VARCHAR2--
  v_Message VARCHAR(2000):=''; --OBTG:VARCHAR2--
  v_Result NUMERIC:=1; -- 0=failure
  v_Record_ID VARCHAR(32); --OBTG:VARCHAR2--
  v_User_ID VARCHAR(32):='0'; --OBTG:VARCHAR2--
  v_Org_ID VARCHAR(32); --OBTG:VARCHAR2--
  v_Client_ID VARCHAR(32); --OBTG:VARCHAR2--
  v_DocStatus VARCHAR(32);
	v_count_record numeric;
	v_shift_c_bpartner_id varchar(32);
	v_ta_shift_id_1 varchar(32);
	v_name_shift varchar(100);
	v_double_shift numeric;
	v_count_day_shift interval;

--

	v_c_bpartner_id VARCHAR(32);
	v_ta_c_bp_shift_id VARCHAR(32);
	v_ta_shift_id VARCHAR(32);
	v_validfrom timestamp;
	v_validto timestamp;
	v_isactive bpchar;
	v_em_hris_validto timestamp
	v_issale bpchar
	v_name varchar(240);
	v_count_day interval;
  --  Parameter
  --TYPE RECORD IS REFCURSOR;
    Cur_Parameter RECORD;
    cur_ta_c_bp_shift record;
 

   
  BEGIN
    RAISE NOTICE '%','Updating PInstance - Processing ' || p_PInstance_ID ;
    v_ResultStr:='PInstanceNotFound';
    PERFORM AD_UPDATE_PINSTANCE(p_PInstance_ID, NULL, 'Y', NULL, NULL) ;
  BEGIN --BODY
    -- Get Parameters, berfungsi untuk membaca record pada window yang aktif
    v_ResultStr:='ReadingParameters';
    FOR Cur_Parameter IN
      (SELECT i.Record_ID, i.ad_client_id, i.ad_org_id, i.AD_User_ID, p.ParameterName, p.P_String, p.P_Number, p.P_Date
      FROM AD_PInstance i
      LEFT JOIN AD_PInstance_Para p
        ON i.AD_PInstance_ID = p.AD_PInstance_ID
      WHERE i.AD_PInstance_ID = p_PInstance_ID
      ORDER BY p.SeqNo
      )
    LOOP
      v_Record_ID := Cur_Parameter.Record_ID; --movement_id
      v_User_ID := Cur_Parameter.AD_User_ID;
	  v_Org_ID := Cur_Parameter.ad_org_id;
      v_Client_ID := Cur_Parameter.ad_client_id;
    END LOOP; -- Get Parameter
--Diatas penting
       raise notice '%', 'jalan';
--    loop ta_c_bp_shift

    for cur_ta_c_bp_shift in
    (

      
    			select DISTINCT tcbs.c_bpartner_id
			    from ta_c_bp_shift tcbs
			    where tcbs.ad_client_id = v_Client_ID
			   
	
    )
    loop

				select tcbs.c_bpartner_id , tcbs.ta_c_bp_shift_id ,tcbs.ta_shift_id , tcbs.validfrom , tcbs.validto, cb.isactive , cb.em_hris_validto,tcbs.issale,
    			cb.name,(tcbs.validto::timestamp - tcbs.validfrom::timestamp) as count_day
    			into v_c_bpartner_id, v_ta_c_bp_shift_id, v_ta_shift_id,v_validfrom, v_validto,v_isactive, v_em_hris_validto, v_issale,
    			v_name,v_count_day
			    from (select * from ta_c_bp_shift where c_bpartner_id = cur_ta_c_bp_shift.c_bpartner_id
			    ) tcbs 
			    left join c_bpartner cb 
			    on  cb.c_bpartner_id = tcbs.c_bpartner_id
			    where tcbs.ad_client_id = v_Client_ID
			    and cb.isactive = 'Y'
			    ORDER BY validto desc
			    limit 1
			    
--       Bloking bila validto koskng di empolee information
      	 if (v_em_hris_validto is null ) then
			raise exception '%', v_name ||' Valid To Date Masih kosong !!!' ;
		else
		
       
--    get count record shift   
		SELECT COUNT(c_bpartner_id)
		into v_count_record
		from ta_c_bp_shift
    	where c_bpartner_id =v_c_bpartner_id ;
   
--	  bloking jika record shift kurang dari 2
	 	if (v_count_record < 2) then
			raise exception '%', 'Jumlah record yang di buat kurang dari 2' ||v_name || ' - ' || v_count_record;
	  	end if;
	 
		 
		 select count(ta_c_bp_shift_id ) ,c_bpartner_id
		 into v_double_shift
		 from ta_c_bp_shift
		 where c_bpartner_id = v_c_bpartner_id
		 group by c_bpartner_id , ta_shift_id ,date_part('month',validfrom)
		 order by count(ta_c_bp_shift_id ) desc
		 limit 1;
	
--	  bloking jika shift memliki shift yang sam dua kali brtururt turut
--		 if ( v_double_shift > 1 and cur_ta_c_bp_shift.issale = 'N') then
--		 	raise exception '%', cur_ta_c_bp_shift.name || ' - Memilik Shift sama selama dua pekan di dalam bulan yang sama !!!' ;
--		 end if;
--		 	
	--	 get jumlah dia kerja
		 if(v_count_day<interval '13  day') then
			 v_count_day_shift := v_count_day + (interval '14  day' - v_count_day);
--			 raise exception '%', ' Kurang dari 13'||v_count_day_shift ;
		 else
		 	v_count_day_shift :=v_count_day + interval '1 days';
	--	 raise exception '%', ' hari Lebih dari 13'|| cur_ta_c_bp_shift.count_day  ;
		 end if;
		
	-- ambil shift sebelunya
		select ta_shift_id 
		into v_ta_shift_id_1
		from ta_c_bp_shift
		where c_bpartner_id = v_c_bpartner_id
		and ta_c_bp_shift_id != v_ta_c_bp_shift_id
		order by validto desc 
		limit 1;
	
	if (v_issale = 'N') then
		
		insert into ta_c_bp_shift (ta_c_bp_shift_id ,
		ad_client_id,
		ad_org_id,
   		created,
   		createdby,
   		updated,
   		updatedby,
   		isactive,
   		c_bpartner_id,
   		ta_shift_id ,
   		validfrom ,
   		validto,
   		issale)
   		values( get_uuid(),
   		v_Client_ID,
	    v_Org_ID,
	    now(),
	    v_User_ID,
	    now(),
	    v_User_ID,
	    'Y',
	    v_c_bpartner_id,
	    v_ta_shift_id_1,
	    v_validto + interval '1 days',
	    v_validto + v_count_day_shift,
	   'N');
	  
	  elseif (v_issale = 'Y') then
	  	insert into ta_c_bp_shift (ta_c_bp_shift_id ,
		ad_client_id,
		ad_org_id,
   		created,
   		createdby,
   		updated,
   		updatedby,
   		isactive,
   		c_bpartner_id,
   		ta_shift_id ,
   		validfrom ,
   		validto,
   		issale)
   		values( get_uuid(),
   		v_Client_ID,
	    v_Org_ID,
	    now(),
	    v_User_ID,
	    now(),
	    v_User_ID,
	    'Y',
	    v_c_bpartner_id,
	    v_ta_shift_id_1,
	    v_validto + interval '1 days',
	    v_validto + v_count_day_shift,
	   'Y');
	  
	end if;  
   end if;
    end loop;

  
	v_Result := 1;  --success
	v_Message :=  'Create Success !!!';

	
  END; --BODY
  
  IF(p_PInstance_ID IS NOT NULL) THEN
    PERFORM AD_UPDATE_PINSTANCE(p_PInstance_ID, v_User_ID, 'N', v_Result, v_Message) ;
  END IF;
 
EXCEPTION
WHEN OTHERS THEN
  v_ResultStr:= '@ERROR=' || SQLERRM;
  RAISE NOTICE '(ta_generate_shift) %', v_ResultStr;
  -- ROLLBACK;
  PERFORM AD_UPDATE_PINSTANCE(p_PInstance_ID, v_User_ID, 'N', 0, v_ResultStr);
--	RAISE EXCEPTION '(ta_generate_shift) %' , SQLERRM; 
--  RETURN;
END ;$function$
;




