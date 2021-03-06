Use FXAPPLICATION
Go
Alter procedure sysmaint.taskCreateRepl
 as
 Begin
 
	--------------------------------------------------------------
	-- Init variables
	--------------------------------------------------------------
 	Declare
 		@publication sysname,
		@dbname nvarchar(128),
		@SnapShotJobLogin nvarchar(257),
		@SnapShotJobPassword sysname,
		@LogReaderJobLogin nvarchar(257),
		@LogReaderJobPassword sysname
	Set @dbname = db_name()

	Select
		@SnapShotJobLogin = rEnv.SnapShotJobLogin,
		@SnapShotJobPassword = rEnv.SnapShotJobPassword,
		@LogReaderJobLogin = rEnv.LogReaderJobLogin,
		@LogReaderJobPassword = rEnv.LogReaderJobPassword
	 From sysmaint.ReplEnvironment as rEnv
	 Inner Join sysmaint.Environment as Env on rEnv.EnvironmentID = Env.EnvironmentID
	 Where
		Env.ServerName = @@SERVERNAME

	--------------------------------------------------------------
	-- Setup DB/Server
	--------------------------------------------------------------
	-- Determin if DB setup for replication
	Declare @DBHelpResults table(name varchar(255), id int, transpublish bit, mergepublish bit, dbowner bit, dbreadonly bit)
	Insert into @DBHelpResults (name, id, transpublish, mergepublish, dbowner, dbreadonly)
	 Exec sp_helpreplicationdboption @dbname = @dbname

	If not exists (Select * from @DBHelpResults where name = db_name() and transpublish = 1) -- if not set it up
	 exec sp_replicationdboption @dbname = @dbname, @optname = N'publish', @value = N'true' -- setup replication

	Declare @LogReaderHelpResults table(
		id int,
		name varchar(1000),
		publisher_security_mode smallint,
		publisher_login sysname,
		publisher_password nvarchar(524) ,
		job_id uniqueidentifier,
		job_login nvarchar(512),
		job_password sysname)
	Insert into @LogReaderHelpResults (id, name, publisher_security_mode, publisher_login, publisher_password, job_id, job_login, job_password)
	Exec sp_helplogreader_agent

	If not exists (select * from @LogReaderHelpResults)
	 exec [FXAPPLICATION].sys.sp_addlogreader_agent @job_login = @LogReaderJobLogin, @job_password = @SnapShotJobPassword, @publisher_security_mode = 1, @job_name = null

	Exec sysmaint.taskCreateReplPublications
	Exec sysmaint.taskCreateReplArticles
	Exec sysmaint.taskCreateReplSubscriptions

End
Go

--Exec sysmaint.taskCreateRepl
