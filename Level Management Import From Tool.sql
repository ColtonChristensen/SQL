


---------------------------------------------------------
-----------------Replen Level Management-----------------
---------------------------------------------------------
update Sandbox.fanzz.replen_level_management
set code = null 
where code = ''

update Sandbox.fanzz.replen_level_management
set Expire = null 
where Expire = ''

;
-------------------------------------------------------------
------------------------Back up table------------------------
-------------------------------------------------------------
if (select cast(max(backupdt) as date) from Sandbox.fanzz.replen_level_backup) <> cast(getdate() as date)
begin 
print 'Backup Table';
insert into sandbox.fanzz.replen_level_backup 
select r.*, getdate() BackupDt 
from Sandbox.fanzz.replen_level  r
end 
;



--------------------------------------------------------------
----------------Archive Replen Level Management---------------
--------------------------------------------------------------
print 'Archive Replen Level Management'

insert into sandbox.fanzz.Replen_level_Management_Archive
select *
from Sandbox.fanzz.replen_level_management m 
where cast(m.Upload as date) <= cast(getdate() -15 as date);


delete from Sandbox.fanzz.replen_level_management
where cast(Upload as date) <= cast(getdate() -15 as date);



------------------------------------------------------------------
-------------------Insert Scheduled Levels------------------------
------------------------------------------------------------------
print 'Insert Scheduled Levels'
insert into sandbox.fanzz.replen_level_management
select
s.ItemID
,s.AXTeam
,s.Player
,s.Color
,s.AXStore
,s.Level
,s.Expire
,getdate() upload
,s.Code

from Sandbox.fanzz.Replen_Level_Schedule s
where LaunchDate between cast(getdate() -2 as date) and cast(getdate() as date) --Try for 3 days just incase something fails

				and not exists (select * from Sandbox.fanzz.replen_level r1 
										where r1.Itemid = s.Itemid
											and r1.AXTeam = s.Axteam
											and r1.Player = s.Player
											and r1.Color = s.Color
											and r1.AXStore = s.AXStore
											and r1.InvntryLevel = s.Level
											and r1.LevelEndDt is null)
				and not exists (select * from Sandbox.fanzz.replen_level_management m
					where m.Itemid = s.Itemid
						and m.AXTeam = s.Axteam
						and m.Player = s.Player
						and m.Color = s.Color
						and m.AXStore = s.AXStore
						and m.Level = s.Level
						and cast(m.Upload as date) = cast(getdate() as date))

-----------------------------------------
--------Visiting Team Logic--------------
-----------------------------------------
Print 'Visiting Team Logic '

insert into sandbox.fanzz.replen_level_management
select
p.Itemid
,p.Axteam
,p.player
,p.Color
,s.AXStore
--,r.InvntryLevel
,case when coalesce(r.invntrylevel,0) < 6 then 6
		else r.InvntryLevel end New_Level
,null expire
,getdate() Upload
,'Vsting' Code

from Sandbox.fanzz.visiting_product p
	join Sandbox.fanzz.Visiting_Schedule s
		on p.axteam = s.Opponent
			and cast(getdate() as date) between dateadd(dd,-21,s.Date) and dateadd(dd,-7,s.date)
				and not exists (select * from Sandbox.fanzz.replen_level r1 
										where r1.Itemid = p.Itemid
											and r1.AXTeam = p.Axteam
											and r1.Player = p.Player
											and r1.Color = p.Color
											and r1.AXStore = s.AXStore
											and r1.InvntryLevel >= 6
											and r1.LevelEndDt is null
											and r1.code = 'Vsting')
				and not exists (select * from Sandbox.fanzz.replen_level_management m
					where m.Itemid = p.Itemid
						and m.AXTeam = p.Axteam
						and m.Player = p.Player
						and m.Color = p.Color
						and m.AXStore = s.AXStore
						and m.Level >= 6
						and m.code = 'Vsting'
						and cast(m.Upload as date) = cast(getdate() as date))

	left join Sandbox.fanzz.Replen_Level r
		on r.Itemid = p.Itemid
			and r.AXTeam = p.Axteam
			and r.Player = p.Player
			and r.Color = p.Color
			and r.AXStore = s.AXStore
			and r.LevelEndDt is null




-------------------------------------------------------  -----------------Check on this
----------Shut down visiting team level----------------
-------------------------------------------------------
print 'Shut Down Expired Visiting Team Levels'

insert into Sandbox.fanzz.replen_level_management
select
p.Itemid
,p.Axteam
,p.player
,p.Color
,s.AXStore
,coalesce(r2.InvntryLevel,0) Old_Level
,r2.Expire expire
,getdate() Upload
,r2.Code Code
--,r.code 
--,r.InvntryLevel
--,r.LevelStartDt

from Sandbox.fanzz.visiting_product p
	join Sandbox.fanzz.Visiting_Schedule s
		on p.axteam = s.Opponent
			--and '2015-09-17' >= dateadd(dd,-5,s.date)
			and cast(getdate() as date) >= dateadd(dd,-5,s.date)
	join Sandbox.fanzz.Replen_Level r
		on r.Itemid = p.Itemid
			and r.AXTeam = p.Axteam
			and r.Player = p.Player
			and r.Color = p.Color
			and r.AXStore = s.AXStore
			and r.LevelEndDt is null
			and r.Code = 'Vsting'
	left join Sandbox.fanzz.Replen_Level r2
		on r2.Itemid = r.Itemid
			and r2.AXTeam = r.Axteam
			and r2.Player = r.Player
			and r2.Color = r.Color
			and r2.AXStore = r.AXStore
			and r2.LevelEndDt = dateadd(dd,-1,r.LevelStartDt)

			
		and not exists (select * from Sandbox.fanzz.replen_level_management m
			where m.Itemid = p.Itemid
				and m.AXTeam = p.Axteam
				and m.Player = p.Player
				and m.Color = p.Color
				and m.code = r2.Code
				and m.AXStore = s.AXStore
				and m.Level = coalesce(r2.InvntryLevel,0)
				and cast(m.Upload as date) = cast(getdate() as date))

		and not exists (select * from Sandbox.fanzz.replen_level r1 
						where r1.Itemid = r.Itemid
							and r1.AXTeam = r.Axteam
							and r1.Player = r.Player
							and r1.Color = r.Color
							and r1.AXStore = r.AXStore
							and r1.InvntryLevel = r2.InvntryLevel
							and r1.LevelEndDt is null
							and r1.Code = r2.Code)

--select * from Sandbox.fanzz.replen_level_management where itemid = '100079097' and axteam = 'Denver Broncos -V1' and color = 'Orange' and axstore = 'MOB01'	order by Upload
	
				
---------------------------------------------------
-------------Zero expired Levels-------------------
---------------------------------------------------
print 'Zero Expired Levels'
insert into sandbox.fanzz.replen_level_management
select
r.ItemID
,r.AXTeam
,r.Player
,r.Color
,r.AXStore
,0 Level
,r.Expire
,getdate() upload
,'Expired' Code

from Sandbox.fanzz.Replen_Level r
--where expire <= cast(getdate() as date)
where expire between cast(getdate() -2 as date) and cast(getdate() as date) --Try for 3 days just incase something fails
and r.LevelEndDt is null

		and not exists (select * from Sandbox.fanzz.replen_level_management m
			where m.Itemid = r.Itemid
				and m.AXTeam = r.Axteam
				and m.Player = r.Player
				and m.Color = r.Color
				and m.AXStore = r.AXStore
				and m.Level = 0)

		and not exists (select * from Sandbox.fanzz.replen_level r1 
						where r1.Itemid = r.Itemid
							and r1.AXTeam = r.Axteam
							and r1.Player = r.Player
							and r1.Color = r.Color
							and r1.AXStore = r.AXStore
							and r1.InvntryLevel = 0
							and r1.LevelEndDt is null)


;

------------------------------------------------------------
----------------Clearance Markdown Levels-------------------
------------------------------------------------------------
Print 'Clearance Markdown Levels'

declare @md3 date
set @md3 = (select max(upload) from Sandbox.fanzz.replen_level_management m where code = 'MD3')

if @MD3 < cast(getdate() as date) -- only do this once per day
begin


-----------------------UTX01-------------------
insert into sandbox.fanzz.replen_level_management
select
i.ItemID
,i.AXTeam
,i.Player
,i.Color
,'UTX01' AXstore
,20 Level
,null Expire
,getdate() Upload
,'MD3' Code
--,i.liquidationstatus
--,sum(PhysicalOnHand)
from (select
			i.DistinctProductVariant
			,i.itemid
			,i.axteam
			,i.player
			,i.color
			,i.LiquidationStatus
			,max(i.LastReceived) LastRecieved
			from dw.fanzz.dim_item i
				where i.LiquidationStatus in ('Markdown3','Clearance Center 1','Clearance Center 2','Markdown4','COLUMBUS DAY 2015','SACS')
				and DistinctProductVariant is not null
			group by 

			i.DistinctProductVariant
			,i.itemid
			,i.axteam
			,i.player
			,i.color
			,i.LiquidationStatus
				)i
	join Sandbox.fanzz.onhand oh
		on i.DistinctProductVariant = oh.DistinctProductVariant
			and oh.InventoryZone = 'MEZ'
			and oh.InvntryEndDt is null
			and oh.PhysicalOnHand > 0
			and i.LastRecieved < cast(getdate() - 15 as date)

			where not exists (select * from Sandbox.fanzz.Replen_Level r
								where r.AXStore = 'UTX01'
									and r.LevelEndDt is null
									and r.InvntryLevel > 0
									and r.Itemid = i.ItemID
									and r.AXTeam = i.AXTeam
									and r.Player = i.Player
									and r.Color = i.Color)

				
group by 
i.ItemID
,i.AXTeam
,i.Player
,i.Color
--,i.liquidationstatus


 
----------------------Clearance Hubs----------------------------
print 'Clearance Hubs'
insert into sandbox.fanzz.replen_level_management
select
i.ItemID
,i.AXTeam
,i.Player
,i.Color
,t.AXStore
,case when t.AvgRank = 'A' then 12
		when t.AvgRank = 'B' then 8
		end Level
,null Expire
,getdate() Upload
,'MD3' Code
--,sum(PhysicalOnHand)
from (select distinct
			i.DistinctProductVariant
			,i.itemid
			,i.axteam
			,i.player
			,i.color
			,i.LiquidationStatus
			,i.BuyerGroup
			,i.League
			from dw.fanzz.dim_item i
				where i.LiquidationStatus in ('Markdown3','Markdown2')
				and DistinctProductVariant is not null
				)i
	join Sandbox.fanzz.onhand oh
		on i.DistinctProductVariant = oh.DistinctProductVariant
			and oh.InventoryZone = 'MEZ'
			and oh.InvntryEndDt is null
			and oh.PhysicalOnHand > 0

	join Sandbox.fanzz.TeamDef t
		on t.BuyerGroup = i.buyergroup
			and t.AXTeam = i.AXTeam
			and t.League = i.League
			and t.AvgRank in ('A','B')

	and t.axstore in (select distinct hub from sandbox.fanzz.clearance_hub)  --- Clearance Hubs
			where not exists (select * from Sandbox.fanzz.Replen_Level r
								where r.AXStore = t.AXStore
									and r.LevelEndDt is null
									and r.InvntryLevel >= case when t.AvgRank = 'A' then 12 when t.AvgRank = 'B' then 8 end 
									and r.Itemid = i.ItemID
									and r.AXTeam = i.AXTeam
									and r.Player = i.Player
									and r.Color = i.Color)
	
group by 
i.ItemID
,i.AXTeam
,i.Player
,i.Color
,t.AXStore
,case when t.AvgRank = 'A' then 12
		when t.AvgRank = 'B' then 8
		 end

order by 1,2,3,4,5,6,7


----------------------------------------------------------------------
----------------Shut down clearance center levels in stores-----------
----------------------------------------------------------------------
print 'Shut down clearance levels in stores'
--select * from Sandbox.fanzz.replen_level_management where itemid = '100041036' and AXTeam = 'Pittsburgh Steelers -V1' and AXStore = 'CAN04'
insert into sandbox.fanzz.replen_level_management
select
i.ItemID
,i.AXTeam
,i.Player
,i.Color
,r.axstore
,0 Level
,null Expire
,getdate() Upload
,'MD3' Code
--,i.liquidationstatus
--,sum(PhysicalOnHand)
from (select
			i.DistinctProductVariant
			,i.itemid
			,i.axteam
			,i.player
			,i.color
			,i.LiquidationStatus
			,max(i.LastReceived) LastRecieved
			from dw.fanzz.dim_item i
				where i.LiquidationStatus in ('Clearance Center 1','Clearance Center 2','Markdown4','COLUMBUS DAY 2015')
				and DistinctProductVariant is not null
			group by 

			i.DistinctProductVariant
			,i.itemid
			,i.axteam
			,i.player
			,i.color
			,i.LiquidationStatus
				)i

	join sandbox.fanzz.replen_level r
		on r.itemid = i.itemid
			and r.axteam = i.axteam
			and r.player = i.player
			and r.color = i.Color
			and r.LevelEndDt is null
			and r.AXStore <> 'UTX01'
			and r.AXStore <> 'Ecom'
			and r.InvntryLevel > 0
			and i.lastrecieved < cast(getdate() - 15 as date)

			order by 1,2,3,4,5,6


-----------------------------------------------------------------
-----Remove MD3 levels when they are no longer on markdown-------
-----------------------------------------------------------------
print 'Remove MD3 levels'
insert into Sandbox.fanzz.replen_level_management
select
r.Itemid
,r.AXTeam
,r.Player
,r.Color
,r.AXStore
,0 level
,null expire
,GETDATE() Upload
,null Code
from sandbox.fanzz.replen_level r
	where levelenddt is null
		and code = 'MD3'
		and not exists (select * from dw.fanzz.dim_item i
							where i.itemid = r.itemid
								and i.axteam = r.axteam
								and i.player = r.player
								and i.color = r.color
								and i.liquidationstatus in ('Markdown3','CLEARANCE CENTER 1','Clearance Center 2','MARKDOWN4'))
		and axstore in (select distinct hub from sandbox.fanzz.clearance_hub) 

		select * from sandbox.fanzz.clearance_hub
----------------------------------------------------------------------------
------------------- Selectivly shut down MD3/MD4 Levels---------------------
-------------------- After 30 days to test new price -----------------------	
----------------------------------------------------------------------------
print 'Selectivly shut down md3/md4 levels after price change'
insert into Sandbox.fanzz.replen_level_management
select 
r.itemid
,r.AXTeam
,r.Player
,r.Color
,r.AXStore
,0 level
,null Expire
,getdate() Upload
,'MD3' Code
from  Sandbox.fanzz.Replen_Level r
			join 
		(select 
		i.itemid
		,i.axteam
		,i.player
		,i.color
		,i.LiquidationStatus
		,min(i.RUNDATE) Start
		,row_number() over(Partition by itemid,axteam,player,color order by min(i.rundate) desc) rn

		from dw.fanzz.Dim_Item_Cached i
			where liquidationstatus in ('MARKDOWN3','SACS','MARKDOWN4')

		group by 
		i.itemid
		,i.axteam
		,i.player
		,i.color
		,i.LiquidationStatus) i

		on i.itemid = r.itemid
				and i.AXTeam = r.AXTeam
				and i.Player = r.Player
				and i.Color = r.Color
				and r.LevelEndDt is null
				and i.rn = 1 --get most recent change
				and r.InvntryLevel > 0
				and r.AXStore not in (select distinct hub from sandbox.fanzz.clearance_hub)
				and r.AXStore not in ('Ecom','UTV20') --clearance hubs & bees stadium
		
left join 

	(select 
	ds.axstore
	,i.ItemID
	,i.AXTeam
	,i.Player
	,i.Color
	,sum(s.Quantity) Sold
	from dw.fanzz.dim_item i
		join dw.fanzz.Fact_Sales s
			on i.ItemKey = s.ItemKey
				and i.liquidationstatus in ('MARKDOWN3')
		join dw.fanzz.dim_store ds
			on s.StoreKey = ds.storekey
				and s.SalesDate >= cast(getdate() -30 as date)
				and s.Quantity > 0
	group by 
	ds.axstore
	,i.ItemID
	,i.AXTeam
	,i.Player
	,i.Color)s
		on s.ItemID = r.Itemid
		and s.AXTeam = r.AXTeam
		and s.Player = r.Player 
		and s.Color = r.Color
		and s.AXStore = r.AXStore
		where  case when cast(getdate() - 30 as date) >= i.start and coalesce(s.Sold,0)/InvntryLevel <= .33 then 0 end = 0
			and exists (select * from Sandbox.fanzz.Replen_Level rr
							where r.AXStore = rr.AXStore
								and r.Itemid = rr.Itemid
								and r.AXTeam = rr.AXTeam
								and r.Player = rr.Player
								and r.Color = rr.Color
								and r.InvntryLevel > 0
								and r.LevelEndDt is null)
;
end
----------------------------------------------------
-----------------Zero Drop Ship Levels--------------
----------------------------------------------------
print 'Zero Drop Ship Levels'
insert into Sandbox.fanzz.replen_level_management
select 
i.ItemID
,i.AXTeam
,i.Player
,i.Color
,'Ecom' AXStore
, 0 Level
,null Expire
,getdate() Upload
,'DROPSHIP' Code
from sandbox.fanzz.replen_level r
join
	(select Distinct
	i.ItemID
	,i.AXteam
	,i.Player
	,i.color
	from Sandbox.fanzz.dim_item i
		join Sandbox.fanzz.Drop_Ship d
			on i.RetailVariantID = d.RetailVariantId) i
				on i.itemid = r.itemid
					and i.axteam = r.AXTeam
					and i.Player = r.Player
					and i.Color = r.Color
					and r.LevelEndDt is null
					and r.axstore = 'Ecom'
				where r.InvntryLevel > 0
;
------------Remove Duplicates---------------------------------
with x as   (select  *,rn = row_number()
            over(PARTITION BY itemid, axteam, player, color, axstore, upload order by "level" desc)
            from sandbox.fanzz.replen_level_management)

delete from x
where rn > 1
;
----------------------------------------------------------


IF OBJECT_ID('sandbox.fanzz.Size_Scale_Item') IS NOT null
BEGIN
DROP TABLE sandbox.fanzz.Size_Scale_Item
END;
print 'Create size_scale_item'
select distinct
i.itemid
,i.axteam
,i.player
,i.color
,t.Scale_type
,count(i.Size) Size_Count
into sandbox.fanzz.Size_Scale_Item
from dw.fanzz.Dim_Item i
	 join Sandbox.fanzz.Size_Scale_Type t
		on i.Size = t.Size
			 and i.Division = t.Division
			and itemid is not null
			--where  i.itemid = '100076753' and i.axteam = 'Salt Lake Bees -V1' and i.color = 'black' 

group by
i.itemid
,i.axteam
,i.player
,i.color
,t.Scale_type
		order by 1,2,3,4;


-----Keep the largest count of sizes for a size group----------------------------
with x as   (select  *,rn = row_number()
            over(PARTITION BY itemid, axteam, player, color order by Size_Count desc)
            from sandbox.fanzz.Size_Scale_Item)

delete from x
where rn > 1

;

--select * from sandbox.fanzz.Size_Scale_Item where itemid = '100075618'
--select * from dw.fanzz.dim_item where itemid = '100075618'
--select * from Sandbox.fanzz.Size_Scale_Type

declare @Update date

set @update = (select cast(max(levelstartdt) as date) from Sandbox.fanzz.Replen_Level)

if @Update = cast(getdate() as date) --

begin
	set @Update = getdate() --Do nothing
end

else
	begin

	--select max(levelenddt) from sandbox.fanzz.replen_level

Print '';
Print '';
Print 'Changes Made';

update r 
	set r.LevelEndDt = cast(getdate() -1 as date) 
			--select *
			from Sandbox.fanzz.Replen_Level r
			join 
				(select * from
				(select 
				m.Itemid
				,m.AXTeam
				,m.Player
				,m.Color
				,m.AXStore
				,m.Level
				,m.Expire
				,m.Upload
				,m.Code
				,max(upload) over(partition by m.itemid,m.axteam,m.player,m.color,AXStore) max_upload --Only pull the max record for the item
				--,row_number() over(PARTITION BY itemid,AXteam,Player,Color,AXStore order by level desc) rnk --keep out dupes
				from sandbox.fanzz.Replen_Level_management m
				group by 
				m.Itemid
				,m.AXTeam
				,m.Player
				,m.Color
				,m.AXStore
				,m.Level
				,m.Expire
				,m.Upload
				,m.code)a
					where a.upload = a.max_upload
					--and rnk = 1
					and axstore <> 'WHS01') a 

					on r.Itemid = a.Itemid
						and r.AXTeam = a.AXTeam
						and r.Player = a.Player
						and r.Color = a.Color
						and r.AXStore = a.AXStore
						and r.LevelEndDt is null

			where  LevelStartDt <> cast(getdate() as date)
				and ( a.level <> r.InvntryLevel
				 or a.Expire <> r.Expire
				 or a.Code <> r.Code)
				 --and  r.itemid = '100007035' 
				 ;
--select * from Sandbox.fanzz.Replen_Level_management r where r.itemid = '100007035' and r.axteam = 'Golden State Warriors -V1'  and r.Color = 'Royal'  order by upload desc
--select * from Sandbox.fanzz.Replen_Level_transfers r where r.itemid = '100007035' and r.axteam = 'Golden State Warriors -V1'  and r.Color = 'Royal' and towhs = 'CAN01' and player = 'Curry Stephen'
insert into Sandbox.fanzz.Replen_Level
select a.*
 --,r1.invntrylevel,r1.code,r1.expire,r1.levelenddt 
from 
(select
a.Itemid
,a.AXTeam
,a.Player
,a.Color
,r.Vendor
,r.League
,r.Division
,r.Department
,a.AXStore
,a.Level
,r.SizeScaleType
,a.Code
,a.Expire
,cast(getdate() as date) LevelStartDt
,Null LevelEndDt

from

	(select 
	m.Itemid
	,m.AXTeam
	,m.Player
	,m.Color
	,m.AXStore
	,m.Level
	,m.Expire
	,m.Upload
	,m.Code
	,max(upload) over(partition by m.itemid,m.axteam,m.player,m.color,m.AXStore) max_upload
	from sandbox.fanzz.Replen_Level_management m
	
	group by 
	m.Itemid
	,m.AXTeam
	,m.Player
	,m.Color
	,m.AXStore
	,m.Level
	,m.Expire
	,m.Upload
	,m.code)a 

	join Sandbox.fanzz.Replen_Level r
		on r.Itemid = a.Itemid
			and r.AXTeam = a.AXTeam
			and r.Player = a.Player
			and r.Color = a.Color
			and r.AXStore = a.AXStore
			and r.LevelEndDt = cast(getdate() -1 as date)

where 1 = 1
	--and  r.itemid = '100007035' and r.axteam = 'Golden State Warriors -V1'  and r.Color = 'Royal' -- and r.AXStore = 'NHB02'
 and a.upload = a.max_upload
 and (a.level <> r.InvntryLevel
 or a.Expire <> r.Expire
 or a.Code <> r.Code))a
   left join sandbox.fanzz.Replen_Level r1 
					on a.itemid = r1.Itemid
					and a.AXTeam = r1.AXTeam
					and a.Player = r1.Player
					and a.Color = r1.Color
					and a.AXStore = r1.AXStore
					--and a.Level = r1.InvntryLevel
					--and a.Expire = r1.Expire
					--and a.Code = r1.Code
					and r1.LevelEndDt is null
					where r1.AXStore is null-- Do not insert records that are already current
 ;
 
 end




-------------------------------------------------------------------------------------
---------------------------Clean up replen_level_management--------------------------
-------------------------------------------------------------------------------------

IF OBJECT_ID('tempdb..#Dim_item') IS null
BEGIN


Select 
i.itemid
,i.axteam
,i.player
,i.color
,i.league
,i.Division
,i.Department
,i.Category6
,i.BuyerGroup
,max(Vendor) Vendor
into #Dim_item
from dw.fanzz.dim_item i 
group by
i.itemid
,i.axteam
,i.player
,i.color
,i.league
,i.Division
,i.Department
,i.Category6
,i.BuyerGroup
END;





------------------------------------------------------------------------------
----------- Reject levels for invalid leagues at league specific stores-------
------------------------------------------------------------------------------

print '--------'
print 'Rejected'
insert into Sandbox.fanzz.replen_level_reject
select m.*,'Invalid League' from Sandbox.fanzz.replen_level_management m  
						join #dim_item i
						
							on i.itemid = m.itemid
								and i.axteam = m.axteam
								and i.Player = m.player
								and i.color = m.color

						where 1=1
						and code <> 'MD3'
						and (  (m.AXStore in ('ORB02','NMB05')  and i.League not in ('NFL','NCAA','Other') )  -- No non football in ORB02
							or ( m.AXStore = 'UTT01' and i.League not in ('NFL','Other') ) -- Only NFL in UTT01
							--or ( m.AXStore = 'UTB01' and i.League = 'NFL')  -- No NFL in UTB01
							or  (m.AXStore = 'UTV20' and i.League not in ('MLB','MiLB') and i.axteam not in ('Salt Lake Bees -V1','LA Angels -V1')) 
							or  ( m.AXStore in ('UTV01','UTV02','UTV03','UTV04','UTV05','UTV06','UTV07','UTV08') and i.League <> 'NBA' and i.axteam not in ('Utah Jazz -v1','Utah Jazz -V2'))  --Only Jazz in the Arena
							or (m.AXStore = 'ORB09' and i.buyergroup = 'MLS' and i.AXTeam <> 'Portland Timbers -V1') -- Only allow Timbers in ORB09
							or (m.AXStore = 'ORB09' and i.buyergroup = 'NHL') --No NHL Apparel in ORB09
							or i.Vendor = 'Unassigned')
							



delete m from Sandbox.fanzz.replen_level_management m  
						join #dim_item i
						
							on i.itemid = m.itemid
								and i.axteam = m.axteam
								and i.Player = m.player
								and i.color = m.color

						where 1=1
						--and code <> 'MD3'
						and (  (m.AXStore in ('ORB02','NMB05')  and i.League not in ('NFL','NCAA','Other') )  -- No non football in ORB02
							or ( m.AXStore = 'UTT01' and i.League not in ('NFL','Other') ) -- Only NFL in UTT01
							--or ( m.AXStore = 'UTB01' and i.League = 'NFL')  -- No NFL in UTB01
							or  (m.AXStore = 'UTV20' and i.League not in ('MLB','MiLB') and i.axteam not in ('Salt Lake Bees -V1','LA Angels -V1')) 
							or  ( m.AXStore in ('UTV01','UTV02','UTV03','UTV04','UTV05','UTV06','UTV07','UTV08') and i.League <> 'NBA' and i.axteam not in ('Utah Jazz -v1','Utah Jazz -V2'))  --Only Jazz in the Arena
							or (m.AXStore = 'ORB09' and i.buyergroup = 'NHL') --No NHL Apparel in ORB09
							or (m.AXStore = 'ORB09' and i.buyergroup = 'MLS' and i.AXTeam <> 'Portland Timbers -V1') -- Only allow Timbers in ORB09
							or i.Vendor = 'Unassigned')


--------------------Venue pocket Stores-----------------------------------
insert into Sandbox.fanzz.replen_level_reject
select m.*,'Invalid Product' from Sandbox.fanzz.replen_level_management m  
						join #dim_item i
						
							on i.itemid = m.itemid
								and i.axteam = m.axteam
								and i.Player = m.player
								and i.color = m.color

						where 1=1
						and code <> 'MD3'
						and ( (m.AXStore = 'UTV03' and i.Division not in ('Headwear','Impulse','Kids Apparel','Kids Outerwear','Services and Loyalty') -- Only kids product in UTV03 
									or m.AXStore = 'UTV03' and i.Division = 'Headwear' and i.Category6 <> 'Kids') -- Only Kids Hats in UTV03
								
								or m.AXStore = 'UTV04' and i.division not in ('Headwear','Impulse','Womens Apparel','Womens Outerwear','Services and Loyalty') --Only Womens product in UTV04
									or m.AXStore = 'UTV04' and i.Division = 'Headwear' and i.Category6 <> 'Womens' --Only womens headwear in UTV04
	
							)


delete m from Sandbox.fanzz.replen_level_management m  
						join #dim_item i
						
							on i.itemid = m.itemid
								and i.axteam = m.axteam
								and i.Player = m.player
								and i.color = m.color

						where 1=1
						--and code <> 'MD3'
						and ( (m.AXStore = 'UTV03' and i.Division not in ('Headwear','Impulse','Kids Apparel','Kids Outerwear','Services and Loyalty') -- Only kids product in UTV03 
									or m.AXStore = 'UTV03' and i.Division = 'Headwear' and i.Category6 <> 'Kids') -- Only Kids Hats in UTV03
								
								or m.AXStore = 'UTV04' and i.division not in ('Headwear','Impulse','Womens Apparel','Womens Outerwear','Services and Loyalty') --Only Womens product in UTV04
									or m.AXStore = 'UTV04' and i.Division = 'Headwear' and i.Category6 <> 'Womens' --Only womens headwear in UTV04
	
							)



---------------------Reject invalid items----------------------
insert into Sandbox.fanzz.replen_level_reject
select m.*, 'Invalid Item' from Sandbox.fanzz.replen_level_management m
	where not exists (select * from dw.fanzz.dim_item i
						where i.itemid = m.itemid
						and i.axteam = m.axteam
						and i.player = m.player
						and i.color = m.color)

delete m from Sandbox.fanzz.replen_level_management m
	where not exists (select * from dw.fanzz.dim_item i
						where i.itemid = m.itemid
						and i.axteam = m.axteam
						and i.player = m.player
						and i.color = m.color)


----------------Reject levels for invalid stores ------------------------

insert into Sandbox.fanzz.replen_level_reject
select m.* ,'Invalid Store' from Sandbox.fanzz.replen_level_management m  where not exists (select * from dw.fanzz.dim_store ds
																					where ds.axstore = m.axstore
																					and ds.activestore = 'Active') 
																					and m.Axstore <> 'Ecom'



Delete  from Sandbox.fanzz.replen_level_management  where not exists (select * from dw.fanzz.dim_store ds
																					where ds.axstore = Sandbox.fanzz.replen_level_management.axstore
																					and ds.activestore = 'Active') 
																					and Sandbox.fanzz.replen_level_management.Axstore <> 'Ecom'
																					;

---------------------------------Remove Duplicates---------------------------------
with x as   (select  *,rn = row_number()
            over(PARTITION BY itemid, axteam, player, color, axstore, upload order by "level" desc)
            from sandbox.fanzz.replen_level_management)

insert into Sandbox.fanzz.replen_level_reject
select x.itemid, x.axteam, x.player, x.color,x.axstore, x.level, x.expire,x.upload,x.code,'Duplicate' from x where rn > 1

;

with x as   (select  *,rn = row_number()
            over(PARTITION BY itemid, axteam, player, color, axstore, upload order by "level" desc)
            from sandbox.fanzz.replen_level_management)

delete from x
where rn > 1
print '--------'
Print '';
Print '';
print 'New items';

insert into sandbox.fanzz.Replen_Level ---Insert levels that dont exist yet

select
c.Itemid
,c.AXTeam
,c.Player
,c.Color
,i.Vendor
,i.League
,i.Division
,i.Department
,c.AXStore
,c.Level
,case when(s.Scale_type is null) then 'NONE' else s.Scale_type end Scale_type
,c.Code
,c.Expire
,cast(getdate() - 1 as date) LevelStartDt
,Null LevelEndDt

--, row_number() over(PARTITION BY a.itemid,a.AXteam,a.Player,a.Color,a.AXStore order by level desc) rw
from

	(select 
	b.Itemid
	,b.AXTeam
	,b.Player
	,b.Color
	,b.AXStore
	,b.level
	,b.Expire
	,b.code

	from sandbox.fanzz.Replen_Level r
		right join 


		(select * from
		(select 
		m.Itemid
		,m.AXTeam
		,m.Player
		,m.Color
		,m.AXStore
		,m.Level
		,m.Expire
		,m.Upload
		,m.code
		,max(upload) over(partition by m.itemid,m.axteam,m.player,m.color,AXStore) max_upload --Only pull the max record for the item
		--,row_number() over(PARTITION BY itemid,AXteam,Player,Color,AXStore order by level desc) rnk --keep out dupes
		from sandbox.fanzz.Replen_Level_management m
		--where m.ItemID = '100001881'
		group by 
		m.Itemid
		,m.AXTeam
		,m.Player
		,m.Color
		,m.AXStore
		,m.Level
		,m.Expire
		,m.Upload
		,m.code)a
			where a.upload = a.max_upload
			--and rnk = 1
			and axstore <> 'WHS01'
			and AXStore <>'CAS12'
			and AXStore <> 'IAB01'
			and AXStore <> 'NVB03'
			and AXStore in (select AXStore from dw.fanzz.dim_store ds where ActiveStore = 'Active'))b

			on b.Itemid = r.Itemid
				and b.AXTeam = r.AXTeam
				and b.Player = r.Player
				and b.Color = r.Color
				and b.AXStore = r.AXStore
				and r.LevelEndDt is null
			where r.InvntryLevel is null)c

			left join Sandbox.fanzz.Size_Scale_Item s --Translate size scale type
			on c.Itemid = s.ItemID
				and c.AXTeam = s.AXTeam
				and c.Player = s.Player
				and c.Color = s.Color

			join (select distinct --Proxy for Dim_item table
				i.itemid
				,i.AXTeam
				,i.Player
				,i.Color
				,i.Vendor
				,i.League
				,i.Division
				,i.Department
				from dw.fanzz.dim_item i
				where itemid in (select distinct itemid from sandbox.fanzz.replen_level_management) --limit to level management
				and vendor <>'' 
				--and i.ItemID = '100001881'
				) i
					on c.Itemid = i.ItemID
						and c.AXTeam = i.AXTeam
						and c.Player = i.Player
						and c.Color =i.Color
						where 1 = 1
							and case when c.AXStore in ('ORB02','NMB05')  and i.League not in ('NFL','NCAA','Other') then 'False' end is null  -- No non football in ORB02
							and case when c.AXStore = 'UTT01' and i.League not in ('NFL','Other') then 'False' end is null -- Only NFL in UTT01
							--and case when c.AXStore = 'UTB01' and i.League = 'NFL' then 'False' end is null -- No NFL in UTB01
							and case when c.AXStore = 'UTV20' and i.League not in ('MLB','MiLB','Other') then 'False' end is null
							and case when c.AXStore in ('UTV01','UTV02','UTV03','UTV04','UTV05','UTV06','UTV07','UTV08') and i.League not in ('NBA','Other') then 'false' end is null --Only NBA in the Arena
							and Vendor <> 'Unassigned'
							--and c.itemid = '100041036' and c.AXTeam = 'Pittsburgh Steelers -V1' and c.AXStore = 'CAN04'
						--select * from Sandbox.fanzz.replen_level_management where 1=1 and itemid = '100047446' and axteam = 'Houston Rockets -V1' and color = 'red' and AXStore= 'TXT01'
						--and c.itemid = '100079016'
						--select distinct division from Sandbox.fanzz.dim_item
print '------------------------------';


delete from Sandbox.fanzz.ReplenExclude;

insert into Sandbox.fanzz.ReplenExclude
select Distinct
itemkey
from dw.fanzz.Dim_Item i
 Join Sandbox.fanzz.Replen_Level r
	on i.ItemID = r.Itemid
		and i.AXTeam = r.AXTeam
		and i.Player = r.Player
		and i.Color = r.Color;


--------------------------------------------------------
-------Figure out Mixed Apha 1 vs. Mixed Alpha 2--------
--------------------------------------------------------
update r
set r.SizeScaleType = a.ScaleType
from Sandbox.fanzz.replen_level r
	join

(select
itemid
,case when count(size) = 2 then 'Mix Alpha 2' 
	when count(size) = 3 then 'Mix Alpha 1' 
	else 'Mix Alpha 1' end ScaleType
from
(select distinct
itemid
,size
from dw.fanzz.dim_item
	where itemid in (select itemid from Sandbox.fanzz.Replen_Level where department = 'Stretch')
	 and size <> '' and size like '%/%')a
group by itemid)a
	on r.Itemid = a.ItemID
	where r.LevelEndDt is null



-----Straighten out wrong size scales-----
update sandbox.fanzz.Replen_Level
set sizescaletype = i.Scale_type
from
Sandbox.fanzz.Replen_Level  r
	 join Sandbox.fanzz.Size_Scale_Item i
		on i.itemid = r.Itemid
		and i.axteam = r.AXTeam
		and i.player = r.Player
		and i.color = r.Color

where r.SizeScaleType <> i.Scale_type
and r.Division <> 'Impulse'



update sandbox.fanzz.Replen_Level
set sizescaletype = i.Scale_type
from
Sandbox.fanzz.Replen_Level  r
	 join Sandbox.fanzz.Size_Scale_Item i
		on i.itemid = r.Itemid
		and i.axteam = r.AXTeam
		and i.player = r.Player
		and i.color = r.Color
		--and i.itemid = '100069659'
where r.SizeScaleType is null
	and r.Division <> 'Impulse'



---------------------------------------------------
----------Ecom - Digital Replenishment-------------
---------------------------------------------------



Declare @Day int
set @Day = (select d.DayOfWeek from dw.fanzz.Dim_Date d where d.Date = cast(getdate() as date))

declare @maxdate date
set @maxdate = (select  cast(max(t.TransferDt) as date) from Sandbox.fanzz.Ecom_Transfers t where t.TransferType = 'Level')



if @Day = 1 and @maxdate <> cast(getdate() as date)--Put transfers in on sunday so they will reserve on monday -- only run once 
begin


insert into Sandbox.fanzz.Ecom_Transfers
select 
i.RetailVariantID
,getdate() Transferdate
,'ECMWHS' StoreKey
,0 TransferQtyOut
,t.QTY TransferQtyIn
,'System' UserName
,'Level' TransferType
,0 Executed

from Sandbox.fanzz.Replen_Level_Transfers  t
	join sandbox.fanzz.dim_item i
		on i.ItemID = t.ItemID
		and i.AXTeam = t.AXTeam
		and i.Player = t.Player
		and i.Color = t.Color
		and i.Size = t.Size

where t.ToWhs = 'Ecom'
and i.RetailVariantID <> ''

end 

print '---------------------------------';
Print 'Generic Size Scales';


insert into Sandbox.fanzz.Size_Scale
select distinct
r.AXStore
,r.Vendor
,r.League
,r.Division
,r.Department
,r.SizeScaleType
,g.Size
,g.sizevalue
,getdate() start
,null nd
,'Generic' Code

from Sandbox.fanzz.Replen_Level r
	join Sandbox.fanzz.Size_Scale_Generic g
		on r.SizeScaleType = g.Scale_type
		and r.Vendor is not null
		--and g.sizevalue <> 0
		--and r.AXStore <> 'Ecom'
		--and r.Itemid = '100075230'
	left join Sandbox.fanzz.Size_Scale s
		on r.Vendor = s.Vendor
		and r.League = s.League
		and r.Division = s.Division
		and r.Department = s.Department
		and r.AXStore = s.AXStore
		and r.SizeScaleType = s.SizeScaleType
		and s.ScaleEndDt is null
		
		
		where s.Size is null
		--and r.AXStore = 'ECOM' and r.AXTeam like 'Dallas Cowboys%' and r.league = 'NFL' and r.Division = 'headwear' and r.Department = 'Fitted' and r.SizeScaleType = 'Numeric 11'
		order by 1,2,3,4,5,6
		

Print '------------------------------------------';
print 'Impulse and Headwear/None size scales';

delete from Sandbox.fanzz.Size_Scale
where Division = 'Impulse'
and SizeScaleType = 'NONE'

insert into Sandbox.fanzz.Size_Scale
select distinct
b.AXStore
,a.Vendor
,a.League
,a.Division
,a.Department
,a.SizeScaleType
,i.Size
,1
,cast(getdate() - 30 as date)
,null
,'Generic'

from

(select distinct
itemid
,AXTeam
,Player
,Color
,Vendor
,League
,Division
,Department
,SizeScaleType

from Sandbox.fanzz.Replen_Level
where Division = 'Impulse'
and SizeScaleType = 'NONE')a
	join (select distinct
		itemid
		,AXTeam
		,Player
		,Color
		,Size
		
		from dw.fanzz.dim_item
		where itemid in (select distinct ItemID from Sandbox.fanzz.Replen_level))i
			on i.ItemID = a.Itemid
				and i.AXTeam = a.AXTeam
				and i.Player = a.Player
				and i.Color = a.Color
				
	cross join
		(select
		axstore
		from dw.fanzz.Dim_Store
		where ActiveStore = 'Active'
		and AXStore is not null
		union 
		select 'Ecom'
		
		)b


delete from Sandbox.fanzz.Size_Scale
where Division = 'Headwear'
and SizeScaleType = 'NONE'

insert into Sandbox.fanzz.Size_Scale
select distinct
b.AXStore
,a.Vendor
,a.League
,a.Division
,a.Department
,a.SizeScaleType
,i.Size
,1
,cast(getdate() - 30 as date)
,null
,'Generic'

from

(select distinct
itemid
,AXTeam
,Player
,Color
,Vendor
,League
,Division
,Department
,SizeScaleType

from Sandbox.fanzz.Replen_Level
where Division = 'Headwear'
and SizeScaleType = 'NONE')a
	join (select distinct
		itemid
		,AXTeam
		,Player
		,Color
		,Size
		
		from dw.fanzz.dim_item
		where itemid in (select distinct ItemID from Sandbox.fanzz.Replen_level))i
			on i.ItemID = a.Itemid
				and i.AXTeam = a.AXTeam
				and i.Player = a.Player
				and i.Color = a.Color
				
	cross join
		(select
		axstore
		from dw.fanzz.Dim_Store
		where ActiveStore = 'Active'
		and AXStore is not null
		union 
		select 'Ecom')b




----------------------------------------------------
---------Update womens pocket store size curves-----
----------------------------------------------------
update sandbox.fanzz.size_scale

set sizevalue = case when size = 'Small' then 0.226923077
					 when size = 'Medium' then 0.283846154
					 when size = 'Large' then 0.227692308
					 when size = 'XL' then 0.157692308
					 when size = '2XL' then 0.103846154
					 when size = 'XS' then 0
					 when size = '3Xl' then 0
					 when size = '4xl' then 0
					 when size = '5xl' then 0
					 when size = '6xl' then 0
					 end
where SizeScaleType = 'Alpha 1'
and code = 'Generic'
and axstore = 'UTV04'