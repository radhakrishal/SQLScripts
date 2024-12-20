/**
 * script-database-users-and-permissions.sql
 *
 * Copyright (C) 2020 by Andreas Schaefer <asc@schaefer-it.net>
 *
 * Create a t-sql script that can be used to restore users and 
 * persmissions on a sql server database
 * 
 * Notes: 
 *   - The script will not script built-in accounts or accounts like '##MS%##'
 *   - The script will warn if running on system databases
 *   - The script will not create users when there is no associated login
 *     So make sure you already (re)created the necessary logins
 *
 * Hint: If you run this in SSMS query window, switch result 
 *       to text (CTRL+T) to get a COPY&PASTE script. ;-)
 *
 * Legal Note:
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, 
 * INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR 
 * PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE 
 * FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR 
 * OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER 
 * DEALINGS IN THE SOFTWARE.
 *
 */
SET NOCOUNT ON

-- Script database context switch
SELECT 'USE [' + DB_NAME() + '];' AS '-- Change to database context'

PRINT '--- ***********************************************************************'
PRINT '--- Do you have a valid backup of your database [' + DB_NAME() + ']? ;-)'
PRINT '--- ***********************************************************************'
PRINT ''

IF DB_NAME() IN ('master', 'model', 'msdb', 'tempdb') BEGIN
  PRINT '*******************************************************'
  PRINT '*** DO NOT RUN THIS FOR master, model, msdb OR tempdb!'
  PRINT '*******************************************************'
END

-- First of all we will bail out missing logins here! They will not be created
SELECT 'IF NOT EXISTS (SELECT * FROM master..syslogins WHERE name = '''+ name +''') PRINT ''*** Login missing for user [' + name + ']! User will not be created!'' ' AS '-- Check for missing logins'
  FROM sys.database_principals
 WHERE type IN ('U', 'S')
   AND ( name NOT IN ('dbo', 'guest', 'sys', 'INFORMATION_SCHEMA') AND name NOT LIKE '##MS%##')
 ORDER BY name ASC

-- Drop all users that we want to recreate 
SELECT 'IF EXISTS (SELECT * FROM sys.database_principals WHERE name = ''' + name +''') DROP USER [' + name + '];' AS '-- Drop user if it exists in database'
  FROM sys.database_principals
 WHERE type IN ('U', 'S')
   AND ( name NOT IN ('dbo', 'guest', 'sys', 'INFORMATION_SCHEMA') AND name NOT LIKE '##MS%##')
 ORDER BY name ASC


-- Create users on database (only if there is a login)
SELECT 'IF EXISTS (SELECT * FROM master..syslogins WHERE name = '''+ name +''') CREATE USER [' + name + '] FOR LOGIN [' + name + '] WITH DEFAULT_SCHEMA=[' + default_schema_name +'];' AS '-- Create user in database if there is a login for it'
  FROM sys.database_principals
 WHERE type IN ('U', 'S')
   AND ( name NOT IN ('dbo', 'guest', 'sys', 'INFORMATION_SCHEMA') AND name NOT LIKE '##MS%##')
 ORDER BY name ASC

-- Add users to roles
SELECT 'IF EXISTS (SELECT * FROM sys.database_principals WHERE name = ''' + DBP.name +''') EXEC sp_addrolemember ''' + DBR.name + ''', ''' + DBP.name + '''' AS '-- Add user to database roles'
  FROM       sys.database_principals   DBP
  INNER JOIN sys.database_role_members DBM ON DBM.member_principal_id = DBP.principal_id
  INNER JOIN sys.database_principals   DBR ON DBR.principal_id = DBM.role_principal_id
 WHERE DBP.type IN ('U', 'S')
   AND ( DBP.name NOT IN ('dbo', 'guest', 'sys', 'INFORMATION_SCHEMA') AND DBP.name NOT LIKE '##MS%##')

-- Now grant special permission on objects. 
-- We do not need to REVOKE them beforehand because DROP <user> already did this for us
  SELECT 
        'IF EXISTS (SELECT * FROM sys.database_principals WHERE name = ''' + DP.name +''') GRANT ' + DBP.permission_name + ' ON [' + SO.name COLLATE Latin1_General_BIN + '] to [' + DP.name + '];' AS '-- Grant special permission on objects if user exists'

  FROM sys.database_principals  DP
  
  JOIN sys.database_permissions DBP ON DBP.grantee_principal_id = DP.principal_id
  JOIN sys.sysobjects           SO  ON  SO.id = DBP.major_id 
 WHERE 
       DP.type IN ('U', 'S') 
   AND ( DP.name NOT IN ('dbo', 'guest', 'sys', 'INFORMATION_SCHEMA') AND DP.name NOT LIKE '##MS%##')
  
 ORDER BY DP.name ASC, SO.name ASC
