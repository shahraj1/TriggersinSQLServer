-- --------------------------------------------------------------------------------
-- --------------------------------------------------------------------------------

-- --------------------------------------------------------------------------------
-- Options
-- --------------------------------------------------------------------------------
USE dbSQL1;     -- Get out of the master database
SET NOCOUNT ON; -- Report only errors
-- --------------------------------------------------------------------------------
-- Drop Tables
-- --------------------------------------------------------------------------------
IF OBJECT_ID('TTeamPlayers') IS NOT NULL DROP TABLE TTeamPlayers
IF OBJECT_ID('TPlayers') IS NOT NULL DROP TABLE TPlayers
IF OBJECT_ID('TTeams') IS NOT NULL DROP TABLE TTeams

IF OBJECT_ID( 'Z_TTeams' )				IS NOT NULL DROP TABLE Z_TTeams --  add drop table for audit table TTeams
IF OBJECT_ID( 'Z_TPlayers' )			   IS NOT NULL DROP TABLE Z_TPlayers -- add drop table for audit table TPlayers
IF OBJECT_ID( 'Z_TTeamPlayers' )				IS NOT NULL DROP TABLE Z_TTeamPlayers --  add drop table for audit table TTeamPlayers


-- --------------------------------------------------------------------------------
-- Step #1.1: Create Tables
-- --------------------------------------------------------------------------------
CREATE TABLE TTeams
(
	 intTeamID			INTEGER	IDENTITY	NOT NULL
	,strTeam			VARCHAR(50)			NOT NULL
	,strMascot			VARCHAR(50)			NOT NULL
	,strModified_Reason		VARCHAR(1000)   --  add reason column

	,CONSTRAINT TTeams_PK PRIMARY KEY ( intTeamID )
)


-- create a Z_ table using original columns and adding UpdatedBY, UpdateOn, strAction, and modified reason
CREATE TABLE Z_TTeams
(
	 intTeamAuditID			INTEGER	Identity	NOT NULL
	,intTeamID				INTEGER				NOT NULL
	,strTeam				VARCHAR(50)			NOT NULL
	,strMascot				VARCHAR(50)			NOT NULL
	,UpdatedBy				VARCHAR(128)		NOT NULL
    ,UpdatedOn				DATETIME			NOT NULL
	,strAction				VARCHAR(1)			NOT NULL
	,strModified_Reason		VARCHAR(1000)		NOT NULL
	,CONSTRAINT Z_TTeams_PK PRIMARY KEY ( intTeamAuditID )
)



CREATE TABLE TPlayers
(
	 intPlayerID		INTEGER	  IDENTITY	NOT NULL
	,strFirstName		VARCHAR(50)			NOT NULL
	,strLastName		VARCHAR(50)			NOT NULL
	,strModified_Reason		VARCHAR(1000)   -- add reason column

	,CONSTRAINT TPlayers_PK PRIMARY KEY ( intPlayerID )
)

-- create a Z_ table using original columns and adding UpdatedBY, UpdateOn, strAction, and modified reason
CREATE TABLE Z_TPlayers
(
	 intPlayerAuditID		INTEGER	IDENTITY	NOT NULL
	,intPlayerID			INTEGER	         	NOT NULL
	,strFirstName			VARCHAR(50)			NOT NULL
	,strLastName			VARCHAR(50)			NOT NULL
	,UpdatedBy				VARCHAR(128)		NOT NULL
    ,UpdatedOn				DATETIME			NOT NULL
	,strAction				VARCHAR(1)			NOT NULL
	,strModified_Reason		VARCHAR(1000)		NOT NULL
	,CONSTRAINT Z_TPlayers_PK PRIMARY KEY ( intPlayerAuditID )
)

CREATE TABLE TTeamPlayers
(
	 intTeamPlayerID	INTEGER IDENTITY	NOT NULL
	,intTeamID			INTEGER				NOT NULL
	,intPlayerID		INTEGER				NOT NULL
	,strModified_Reason		VARCHAR(1000)   -- add reason column
	,CONSTRAINT PlayerTeam_UQ UNIQUE ( intTeamID, intPlayerID )
	,CONSTRAINT TTeamPlayers_PK PRIMARY KEY ( intTeamPlayerID )
)

-- create a Z_ table using original columns and adding UpdatedBY, UpdateOn, strAction, and modified reason
CREATE TABLE Z_TTeamPlayers
(
	 intTeamPlayerAuditID   INTEGER	IDENTITY	NOT NULL
    ,intTeamPlayerID		INTEGER				NOT NULL
	,intTeamID				INTEGER				NOT NULL
	,intPlayerID			INTEGER				NOT NULL
	,UpdatedBy				VARCHAR(128)		NOT NULL
    ,UpdatedOn				DATETIME			NOT NULL
	,strAction				VARCHAR(1)			NOT NULL
	,strModified_Reason		VARCHAR(1000)		NOT NULL
	,CONSTRAINT Z_TTeamPlayers_PK PRIMARY KEY ( intTeamPlayerAuditID )
)

-- --------------------------------------------------------------------------------
-- Step #1.2: Identify and Create Foreign Keys
-- --------------------------------------------------------------------------------
--
-- #	Child								Parent						Column(s)
-- -	-----								------						---------
-- 1	TTeamPlayers						TTeams						intTeamID
-- 2	TTeamPlayers						TPlayers					intPlayerID

-- 1
ALTER TABLE TTeamPlayers ADD CONSTRAINT TTeamPlayers_TTeams_FK
FOREIGN KEY ( intTeamID ) REFERENCES TTeams ( intTeamID )

-- 2
ALTER TABLE TTeamPlayers ADD CONSTRAINT TTeamPlayers_TPlayers_FK
FOREIGN KEY ( intPlayerID ) REFERENCES TPlayers ( intPlayerID )



-- --------------------------------------------------------------------------------
-- Step #1.3: Add at least 3 teams
-- --------------------------------------------------------------------------------
INSERT INTO TTeams ( strTeam, strMascot )
VALUES	 ( 'Reds', 'Mr. Red' )
		,( 'Bengals', 'Bengal Tiger' )
		,( 'Duke', 'Blue Devils' )
		
-- --------------------------------------------------------------------------------
-- Step #1.4: Add at least 3 players
-- --------------------------------------------------------------------------------
INSERT INTO TPlayers ( strFirstName, strLastName )
VALUES	 ( 'Joey', 'Votto' )
		,( 'Joe', 'Morgn' )
		,( 'Christian', 'Laettner' )
		,( 'Andy', 'Dalton' )
		
-- --------------------------------------------------------------------------------
-- Step #1.5: Add at at least 6 team/player assignments
-- --------------------------------------------------------------------------------
INSERT INTO TTeamPlayers ( intTeamID, intPlayerID )
VALUES	 ( 1, 1 )
		,( 1, 2 )
		,( 2, 4 )
		,( 3, 3 )



GO
  -- add trigger
CREATE TRIGGER tblTriggerAuditRecord on TTeams
AFTER UPDATE, INSERT, DELETE 
AS

	 DECLARE @Now datetime
	 DECLARE @Modified_Reason VARCHAR(1000)
	 DECLARE @Action varchar(1)
     SET @Action = ''

    -- Defining if it's an UPDATE (U), INSERT (I), or DELETE ('D')
	-- during triggers SQL Server uses logical tables 'inserted' and deleted'
	-- these tables are only used by the trigger and you cannot write commands 
	-- against them outside of the trigger. 
	-- inserted table - stores copies of affected rows during an INSERT or UPDATE
	-- deleted table - stores copies of affected rows during a DELETE or UPDATE
	BEGIN
    IF (SELECT COUNT(*) FROM INSERTED) > 0 	-- true if it is an INSERT or UPDATE
        IF (SELECT COUNT(*) FROM DELETED) > 0 -- true if it is an DELETE or UPDATE
            SET @Action = 'U'
        ELSE
            SET @Action = 'I'  -- no record in DELETED so it has to be an INSERT
	ELSE
		SET @Action = 'D' --record in INSERTED but not in DELETED so it has to be a delete
    END
    
    SET @Now = GETDATE() -- Gets current date/time

			IF (@Action='I')
				BEGIN --begin Insert info
					INSERT INTO Z_TTeams (intTeamID, strTeam, strMascot, UpdatedBy, UpdatedOn, strAction, strModified_Reason)
					SELECT I.intTeamID, I.strTeam, I.strMascot, SUSER_SNAME(), getdate(), @Action, I.strModified_Reason
					FROM inserted I
						INNER JOIN TTeams T ON T.intTeamID = I.intTeamID
								
				END  --end Insert info
				
			ELSE
				IF (@Action='D')	
					BEGIN   --begin Insert of Delete info 
						INSERT INTO Z_TTeams (intTeamID, strTeam, strMascot, UpdatedBy, UpdatedOn, strAction, strModified_Reason)
						SELECT D.intTeamID, D.strTeam, D.strMascot, SUSER_SNAME(), GETDATE(), @Action, ''
						FROM deleted D 						
					END   --end Delete info				
				ELSE -- @Action='U' 
					BEGIN   --begin Update info get modified reason
						IF EXISTS (SELECT TOP 1 I.strModified_Reason FROM inserted I, TTeams T WHERE I.intTeamID = T.intTeamID 
																	AND I.strModified_Reason <> '')			
							BEGIN -- begin Insert of update info
								INSERT INTO Z_TTeams (intTeamID, strTeam, strMascot, UpdatedBy, UpdatedOn, strAction, strModified_Reason)
								SELECT I.intTeamID, I.strTeam, I.strMascot, SUSER_SNAME(), GETDATE(), @Action, I.strModified_Reason
								FROM TTeams T
									INNER JOIN inserted I ON T.intTeamID = I.intTeamID	
								-- set modified reason column back to ''
								UPDATE TTeams SET strModified_Reason = NULL 
								WHERE intTeamID IN (SELECT TOP 1 intTeamID FROM inserted)
							
						   END   --end update info
						
						ELSE
							BEGIN   --begin if no modified reason supplied
								PRINT 'Error and rolled back, enter modified reason'
								ROLLBACK
							END   --end modified reason error
					END	  --end Update info

GO

------

------

GO
  --  add trigger
CREATE TRIGGER tblTriggerPlayerAuditRecord on TPlayers
AFTER UPDATE, INSERT, DELETE 
AS

	 DECLARE @Now datetime
	 DECLARE @Modified_Reason VARCHAR(1000)
	 DECLARE @Action varchar(1)
     SET @Action = ''

    -- Defining if it's an UPDATE (U), INSERT (I), or DELETE ('D')
	-- during triggers SQL Server uses logical tables 'inserted' and deleted'
	-- these tables are only used by the trigger and you cannot write commands 
	-- against them outside of the trigger. 
	-- inserted table - stores copies of affected rows during an INSERT or UPDATE
	-- deleted table - stores copies of affected rows during a DELETE or UPDATE
	BEGIN
    IF (SELECT COUNT(*) FROM INSERTED) > 0 	-- true if it is an INSERT or UPDATE
        IF (SELECT COUNT(*) FROM DELETED) > 0 -- true if it is an DELETE or UPDATE
            SET @Action = 'U'
        ELSE
            SET @Action = 'I'  -- no record in DELETED so it has to be an INSERT
	ELSE
		SET @Action = 'D' --record in INSERTED but not in DELETED so it has to be a delete
    END
    
    SET @Now = GETDATE() -- Gets current date/time

			IF (@Action='I')
				BEGIN --begin Insert info
					INSERT INTO Z_TPlayers(intPlayerID, strFirstName, strLastName, UpdatedBy, UpdatedOn, strAction, strModified_Reason)
					SELECT I.intPlayerID, I.strFirstName, I.strLastName, SUSER_SNAME(), getdate(), @Action, I.strModified_Reason
					FROM inserted I
						INNER JOIN TPlayers TP ON TP.intPlayerID = I.intPlayerID
								
				END  --end Insert info
				
			ELSE
				IF (@Action='D')	
					BEGIN   --begin Insert of Delete info 
						INSERT INTO Z_TPlayers(intPlayerID, strFirstName, strLastName, UpdatedBy, UpdatedOn, strAction, strModified_Reason)
						SELECT D.intPlayerID, D.strFirstName, D.strLastName, SUSER_SNAME(), GETDATE(), @Action, ''
						FROM deleted D 						
					END   --end Delete info				
				ELSE -- @Action='U' 
					BEGIN   --begin Update info get modified reason
						IF EXISTS (SELECT TOP 1 I.strModified_Reason FROM inserted I, TPlayers TP WHERE I.intPlayerID = TP.intPlayerID 
																	AND I.strModified_Reason <> '')			
							BEGIN -- begin Insert of update info
								INSERT INTO Z_TPlayers (intPlayerID, strFirstName, strLastName, UpdatedBy, UpdatedOn, strAction, strModified_Reason)
								SELECT I.intPlayerID, I.strFirstName, I.strLastName, SUSER_SNAME(), GETDATE(), @Action, I.strModified_Reason
								FROM TPlayers TP
									INNER JOIN inserted I ON TP.intPlayerID = I.intPlayerID	
								-- set modified reason column back to ''
								UPDATE TPlayers SET strModified_Reason = NULL 
								WHERE intPlayerID IN (SELECT TOP 1 intPlayerID FROM inserted)
							
						   END   --end update info
						
						ELSE
							BEGIN   --begin if no modified reason supplied
								PRINT 'Error and rolled back, enter modified reason'
								ROLLBACK
							END   --end modified reason error
					END	  --end Update info

GO

------

------


GO
  --  add trigger
CREATE TRIGGER tblTriggerTeamPlayerAuditRecord on TTeamPlayers
AFTER UPDATE, INSERT, DELETE 
AS

	 DECLARE @Now datetime
	 DECLARE @Modified_Reason VARCHAR(1000)
	 DECLARE @Action varchar(1)
     SET @Action = ''

    -- Defining if it's an UPDATE (U), INSERT (I), or DELETE ('D')
	-- during triggers SQL Server uses logical tables 'inserted' and deleted'
	-- these tables are only used by the trigger and you cannot write commands 
	-- against them outside of the trigger. 
	-- inserted table - stores copies of affected rows during an INSERT or UPDATE
	-- deleted table - stores copies of affected rows during a DELETE or UPDATE
	BEGIN
    IF (SELECT COUNT(*) FROM INSERTED) > 0 	-- true if it is an INSERT or UPDATE
        IF (SELECT COUNT(*) FROM DELETED) > 0 -- true if it is an DELETE or UPDATE
            SET @Action = 'U'
        ELSE
            SET @Action = 'I'  -- no record in DELETED so it has to be an INSERT
	ELSE
		SET @Action = 'D' --record in INSERTED but not in DELETED so it has to be a delete
    END
    
    SET @Now = GETDATE() -- Gets current date/time

			IF (@Action='I')
				BEGIN --begin Insert info
					INSERT INTO Z_TTeamPlayers (intTeamPlayerID, intTeamID, intPlayerID, UpdatedBy, UpdatedOn, strAction, strModified_Reason)
					SELECT I.intTeamPlayerID, I.intTeamID, I.intPlayerID, SUSER_SNAME(), getdate(), @Action, I.strModified_Reason
					FROM inserted I
						INNER JOIN TTeamPlayers TTP ON TTP.intTeamPlayerID = I.intTeamPlayerID
								
				END  --end Insert info
				
			ELSE
				IF (@Action='D')	
					BEGIN   --begin Insert of Delete info 
						INSERT INTO Z_TTeamPlayers (intTeamPlayerID, intTeamID, intPlayerID, UpdatedBy, UpdatedOn, strAction, strModified_Reason)
						SELECT D.intTeamPlayerID, D.intTeamID, D.intPlayerID, SUSER_SNAME(), GETDATE(), @Action, ''
						FROM deleted D 						
					END   --end Delete info				
				ELSE -- @Action='U' 
					BEGIN   --begin Update info get modified reason
						IF EXISTS (SELECT TOP 1 I.strModified_Reason FROM inserted I, TTeamPlayers TTP WHERE I.intTeamPlayerID = TTP.intTeamPlayerID 
																	AND I.strModified_Reason <> '')			
							BEGIN -- begin Insert of update info
								INSERT INTO Z_TTeamPlayers (intTeamPlayerID, intTeamID, intPlayerID, UpdatedBy, UpdatedOn, strAction, strModified_Reason)
								SELECT I.intTeamPlayerID, I.intTeamID, I.intPlayerID, SUSER_SNAME(), GETDATE(), @Action, I.strModified_Reason
								FROM TTeamPlayers TTP
									INNER JOIN inserted I ON TTP.intTeamPlayerID = I.intTeamPlayerID	
								-- set modified reason column back to ''
								UPDATE TTeamPlayers SET strModified_Reason = NULL 
								WHERE intTeamPlayerID IN (SELECT TOP 1 intTeamPlayerID FROM inserted)
							
						   END   --end update info
						
						ELSE
							BEGIN   --begin if no modified reason supplied
								PRINT 'Error and rolled back, enter modified reason'
								ROLLBACK
							END   --end modified reason error
					END	  --end Update info

GO

-- --------------------------------------------------------------------------------
-- Step : Delete a record to test trigger and audit table entry
 --------------------------------------------------------------------------------
----Delete record from TTeamPlayers
--DELETE FROM TTeamPlayers
--WHERE intPlayerID = 3

----Delete record from TPlayers
--DELETE FROM TPlayers
--WHERE intPlayerID = 3

----Delete record from TTeams
--DELETE FROM TTeams
--WHERE intTeamID = 3

----Test using Select statements
--SELECT * FROM TTeamPlayers
--SELECT * FROM Z_TTeamPlayers
--SELECT * FROM TPlayers
--SELECT * FROM Z_TPlayers
--SELECT * FROM TTeams
--SELECT * FROM Z_TTeams

-- --------------------------------------------------------------------------------
-- Step : Update a record to test trigger and audit table entry
 --------------------------------------------------------------------------------
----Update for TTeams
--UPDATE TTeams SET strMascot = 'Red', strModified_Reason = 'mascot changed'
--WHERE strTeam = 'Reds'

----Update for TPLAYERS
--UPDATE TPlayers SET strLastname ='Morgan', strModified_Reason = 'Last Name Changed'
--WHERE strLastName = 'Morgn'

----Update for TTeamPlayers
--UPDATE TTeamPlayers SET  intPlayerID = 2 , strModified_Reason = ' Player Changed'
--WHERE intTeamID = 3

----Test using Select statements
--SELECT * FROM TTEAMS
--SELECT * FROM Z_TTEAMS
--SELECT * FROM TPLAYERS
--SELECT * FROM Z_TPLAYERS
--SELECT * FROM TTeamPlayers
--SELECT * FROM Z_TTeamPlayers

