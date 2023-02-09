DECLARE @publisher_db	VARCHAR(128);
DECLARE @publisher_id	INT;
DECLARE @publication_id INT;
DECLARE @subscriber_db	VARCHAR(128);
DECLARE @subscriber_id	INT;

SET @publisher_db = 'Prod_Data';
SET @publisher_id = 2;
SET @publication_id = 27;
SET @subscriber_db = 'Prod_Report';
SET @subscriber_id = 0;

SELECT  *
FROM    MSsubscriptions
WHERE   status = '0';

UPDATE MSsubscriptions
SET     status = 2
WHERE   status = 0
		AND publisher_id = @publisher_id  -- '2'
        AND publisher_db = @publisher_db  -- 'ProcessData'
        AND publication_id = @publication_id  -- '28'
        AND subscriber_id = @subscriber_id -- '3'
        AND subscriber_db = @subscriber_db -- 'Prod_Report';

--Status of the subscription:
--0 = Inactive
--1 = Subscribed
--2 = Active 
