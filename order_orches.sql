/*
		REQ_ENTITY_TYPE
		-----------------
TASK
PROCESS
PROC_DEFN
SRC_ORDER
ACTN_TRK
DS_CHANGE_DRAFT_HEADER_ID
ORDER
ORA_FOM_ACTION
FLINE

**  -- if not required we can disable  based on the data reverse engg. we saw this join might be useful
*/WITH msg_task_t AS (
    SELECT
        req.header_id
      , req.doo_process_instance_id
      , mt.message_text
      , mb.message_type
      , mb.message_name
      , mb.msg_request_id
      , mb.message_id
      , req.req_entity_type
      , mb.msg_entity_type
    FROM
        fusion.doo_message_requests req
      , fusion.doo_messages_b       mb
      , fusion.doo_messages_tl      mt
    WHERE
            1 = 1
        AND req.active_flag = 'Y'
        AND req.req_entity_type = 'TASK'
        AND req.orchestration_application_id = 10008 --DooApplicationModule oracle.apps.scm.doo.common.applicationModule.DooOrderOrchestrationAM
        AND req.task_instance_id = req.req_entity_id1 -- **
-- b/w msg req and msg     
        AND req.msg_request_id = mb.msg_request_id
        AND mb.msg_entity_type = 'TASK'
--  optional join      
        AND req.req_entity_id1 = mb.msg_entity_id1  -- ** 
        AND req.req_entity_id2 = mb.msg_entity_id2  -- ** 
-- b/w msg and msg tl
        AND mt.message_id = mb.message_id
        AND mt.language = 'US'
		
		--

), msg_fline_t AS (
    SELECT
        req.header_id
      , req.doo_process_instance_id
      , mb.msg_entity_id1 -- to join with f line id below 
      , mt.message_text
      , mb.message_type
      , mb.message_name
      , mb.msg_request_id
      , mb.message_id
      , req.req_entity_type
      , mb.msg_entity_type
    FROM
        fusion.doo_message_requests req
      , fusion.doo_messages_b       mb
      , fusion.doo_messages_tl      mt
    WHERE
            1 = 1
        AND req.active_flag = 'Y'
        AND req.req_entity_type = 'TASK'
        AND req.orchestration_application_id = 10008 --DooApplicationModule oracle.apps.scm.doo.common.applicationModule.DooOrderOrchestrationAM
        AND req.task_instance_id = req.req_entity_id1 -- **
-- b/w msg req and msg       
        AND req.msg_request_id = mb.msg_request_id
        AND mb.msg_entity_type = 'FLINE'		
-- b/w msg and msg tl      
        AND mt.message_id = mb.message_id
        AND mt.language = 'US'
)
-- TASK
SELECT
    oh.source_order_number
  , oh.header_id
  , oh.order_number
  , oh.creation_date
  , oh.source_order_id
  , oh.source_order_system
  , ol.source_line_id
  , oh.sales_channel_code
  , ol.display_line_number
      || '.'
      || fl.fulfill_line_number display_line
  , fl.status_code
  --
  , msg_task_t.message_text
  , msg_task_t.message_type
  , msg_task_t.message_name
  , msg_task_t.msg_request_id
  , msg_task_t.message_id
  , msg_task_t.req_entity_type
  , msg_task_t.msg_entity_type
/*   , MAX(msg_t.message_id)
      OVER(PARTITION BY oh.header_id, fl.fulfill_line_id) max_message_id */
FROM
    fusion.doo_headers_all       oh
  , fusion.doo_lines_all         ol
  , fusion.doo_fulfill_lines_all fl
  , msg_task_t
WHERE
        oh.header_id = ol.header_id
    AND oh.header_id = fl.header_id
    AND fl.line_id = ol.line_id
    AND oh.submitted_flag = 'Y'
		--
    AND oh.header_id = msg_task_t.header_id (+)
    AND fl.process_instance_id = msg_task_t.doo_process_instance_id (+)
	--
    AND oh.order_number = '101008'
    AND trunc(oh.creation_date) >= TO_DATE('14-02-2026', 'DD-MM-YYYY')
UNION
-- FLINE
SELECT
    oh.source_order_number
  , oh.header_id
  , oh.order_number
  , oh.creation_date
  , oh.source_order_id
  , oh.source_order_system
  , ol.source_line_id
  , oh.sales_channel_code
  , ol.display_line_number
      || '.'
      || fl.fulfill_line_number display_line
  , fl.status_code
  --
  , msg_fline_t.message_text
  , msg_fline_t.message_type
  , msg_fline_t.message_name
  , msg_fline_t.msg_request_id
  , msg_fline_t.message_id
  , msg_fline_t.req_entity_type
  , msg_fline_t.msg_entity_type
/*   , MAX(msg_t.message_id)
      OVER(PARTITION BY oh.header_id, fl.fulfill_line_id) max_message_id */
FROM
    fusion.doo_headers_all       oh
  , fusion.doo_lines_all         ol
  , fusion.doo_fulfill_lines_all fl
  , msg_fline_t
WHERE
        oh.header_id = ol.header_id
    AND oh.header_id = fl.header_id
    AND fl.line_id = ol.line_id
    AND oh.submitted_flag = 'Y'
		--
    AND oh.header_id = msg_fline_t.header_id (+)
    AND fl.process_instance_id = msg_fline_t.doo_process_instance_id (+)
    AND fl.fulfill_line_id = msg_fline_t.msg_entity_id1 (+)
	--
    AND oh.order_number = '101008'
    AND trunc(oh.creation_date) >= TO_DATE('14-02-2026', 'DD-MM-YYYY')
ORDER BY
    order_number
  , display_line
  , message_type
  , message_name