update KRIM_GRP_MBR_T  SET ACTV_TO_DT = NULL, LAST_UPDT_DT = NOW() WHERE MBR_TYP_CD = 'P' and MBR_ID IN (
  select PRNCPL_ID FROM KRIM_PRNCPL_T WHERE ENTITY_ID IN (
    select ENTITY_ID FROM KRIM_ENTITY_EMAIL_T WHERE (
      ENTITY_ID IN ('1', '1100', '1131', '1132')
    )
  )
);