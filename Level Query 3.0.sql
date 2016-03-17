

declare @starttime as datetime = getdate()
declare @begin as datetime = getdate()
declare @MaxTransfer datetime
declare @progress varchar(1000)
print 'Start Time: '  + cast(@Starttime as varchar)

------------------------------------------
-------------Get open transfers-----------
------------------------------------------
declare @maxtrans date
set @maxtrans = (select max(rundate) from sandbox.fanzz.Open_Transfer)
set @progress =  @maxtrans;
RAISERROR (@progress, 10, 1) WITH NOWAIT



truncate table sandbox.fanzz.open_transfer;

insert into Sandbox.fanzz.Open_Transfer
 select

tl.transferID
,tl.itemid
,id.INVENTCOLORID player
,id.inventstyleid team
,id.Inventsizeid size
,id.CONFIGID color
,it.TRANSFERSTATUS
,cast(tl.qtytransfer as int) QtyTransfered
,cast(tl.qtyshipped as int) QtyShipped
,cast(tl.QTYRECEIVED as int) QtyRecieved
,it.FROMADDRESSNAME
,it.Toaddressname
,it.CREATEDDATETIME
             
,cast(it.Shipdate as date)
,getdate()
              
			  

    from ods.dax.inventtransferline tl
    join ods.dax.INVENTTRANSFERTABLE it
        on it.TRANSFERID = tl.TRANSFERID
    join ods.dax.INVENTDIM id
        on id.INVENTDIMID = tl.INVENTDIMID
    where cast(it.CREATEDDATETIME as date) between cast(dateadd(dd,-60,getdate())as date) and  cast(getdate() as date)
    --where tl.QTYTRANSFER > tl.QTYSHIPPED
    --and it.TRANSFERSTATUS = 0
    and (FROMADDRESSNAME = 'WHS01'
			or FROMADDRESSNAME = 'WH3PL')
order by it.CREATEDDATETIME asc;



set @progress = ( 'Transfers Updated: ' + cast(datediff(second,@starttime,getdate()) as varchar))
RAISERROR (@progress, 10, 1) WITH NOWAIT

;

set @MaxTransfer = (select max(createddatetime) from Sandbox.fanzz.Open_Transfer);
set @progress = ( 'Max Transfer Date Time: ' + convert(varchar, @maxtransfer))
RAISERROR (@progress, 10, 1) WITH NOWAIT;

--------------------------------------------------------------------------------------------
------------------------------Level Replenishment Code--------------------------------------
--------------------------------------------------------------------------------------------
Declare @MinWOS int
set @MinWOS = 4

IF OBJECT_ID('tempdb..#DCInv') IS NOT null
BEGIN
DROP TABLE #DCInv
END;

IF OBJECT_ID('tempdb..#Ecom_Res') IS NOT null
BEGIN
DROP TABLE #Ecom_Res
END;

IF OBJECT_ID('tempdb..#DCInv2') IS NOT null
BEGIN
DROP TABLE #DCInv2
END;

IF OBJECT_ID('tempdb..#StoreInv') IS NOT null
BEGIN
DROP TABLE #StoreInv
END;

IF OBJECT_ID('tempdb..#StoreInv2') IS NOT null
BEGIN
DROP TABLE #StoreInv2
END;

IF OBJECT_ID('tempdb..#Sales') IS NOT null
BEGIN
DROP TABLE #Sales
END;

IF OBJECT_ID('tempdb..#Sales21') IS NOT null
BEGIN
DROP TABLE #Sales21
END;

IF OBJECT_ID('tempdb..#WOS') IS NOT null
BEGIN
DROP TABLE #WOS
END;

IF OBJECT_ID('tempdb..#DimItem') IS NOT null
BEGIN
DROP TABLE #DimItem
END;

IF OBJECT_ID('tempdb..##need') IS NOT null
BEGIN
DROP TABLE ##need
END;

IF OBJECT_ID('tempdb..#AvlblDays') IS NOT null
BEGIN
DROP TABLE #AvlblDays
END;

IF OBJECT_ID('tempdb..#Level1') IS NOT null
BEGIN
DROP TABLE #Level1
END;

IF OBJECT_ID('tempdb..#Level2') IS NOT null
BEGIN
DROP TABLE #Level2
END;

IF OBJECT_ID('tempdb..#Level3') IS NOT null
BEGIN
DROP TABLE #Level3
END;

IF OBJECT_ID('tempdb..##needranked') IS NOT null
BEGIN
DROP TABLE ##needranked
END;

IF OBJECT_ID('tempdb..#OpenTO') IS NOT null
BEGIN
DROP TABLE #OpenTO
END;

IF OBJECT_ID('tempdb..#SizeLevel') IS NOT null
BEGIN
DROP TABLE #SizeLevel
END;

IF OBJECT_ID('tempdb..#SizeRun') IS NOT null
BEGIN
DROP TABLE #SizeRun
END;

IF OBJECT_ID('tempdb..#h_inv') IS NOT null
BEGIN
DROP TABLE #h_inv
END;
IF OBJECT_ID('tempdb..#h_sales') IS NOT null
BEGIN
DROP TABLE #H_sales
END;

IF OBJECT_ID('tempdb..#New_items') IS NOT null
BEGIN
DROP TABLE #New_items
END;

IF OBJECT_ID('tempdb..#Broken_Size_Runs') IS NOT null
BEGIN
DROP TABLE #Broken_Size_Runs
END;


IF OBJECT_ID('tempdb..#SL1') IS NOT null
BEGIN
DROP TABLE #SL1
END;

IF OBJECT_ID('tempdb..#SL2') IS NOT null
BEGIN
DROP TABLE #SL2
END;

IF OBJECT_ID('tempdb..#Replen_Level') IS NOT null
BEGIN
DROP TABLE #Replen_Level
END;

IF OBJECT_ID('tempdb..#Size_Scale') IS NOT null
BEGIN
DROP TABLE #Size_Scale
END;

-----------------------------------------------
------Set end dates for expired levels---------
-----------------------------------------------
--update Sandbox.fanzz.Replen_Level
--set LevelEndDt = cast(getdate() as date)
--	where expire >= cast(getdate() as date)

-----------------------------------------------
---------Dim Item Recreation - No itemkey------
-----------------------------------------------

set @starttime = getdate()

select distinct
i.DistinctProductVariant
,i.ItemID
,i.AXTeam
,i.Player
,i.Color
,i.Size
,i.Department
,i.BuyerGroup
into #DimItem
from dw.fanzz.Dim_Item i
	where i.itemid in (select itemid from sandbox.fanzz.Replen_level where Levelenddt is null)
		and i.DistinctProductVariant is not null
;
create unique clustered index dim_item_idx on #dimitem
	(DistinctProductVariant,itemid, axteam, player, color, size)
;

set @progress = ( 'Dim_Item Proxy: ' + cast(datediff(second,@starttime,getdate()) as varchar))
RAISERROR (@progress, 10, 1) WITH NOWAIT;
set @starttime = getdate()

-----------------------------------------
-----------Get Current Inventory--------- Live
-----------------------------------------
select 
di.DISTINCTPRODUCTVARIANT
,w.ITEMID
,i.INVENTSTYLEID AXTeam
,i.INVENTCOLORID Player
,i.CONFIGID Color
,i.INVENTSIZEID size
--,wms.INVENTLOCATIONID
--,w.[WAXHIERARCHYLEVEL]
--,wms.waxzoneid
,case when sum(w.AVAILPHYSICAL) < 0  then 0 else sum(w.AVAILPHYSICAL) end Onhand
--,sum(w.AVAILORDERED) AvailOrdered
into #DCInv
--,w.AVAILPHYSICAL

from ods.dax.INVENTDIM i
	join ods.dax.WAXINVENTRESERVE w
		on w.INVENTDIMID = i.INVENTDIMID
			and i.WAXINVENTSTATUSID = 'GOOD'
			and w.WAXHIERARCHYLEVEL = 4
	join ods.dax.WMSLOCATION wms
		on i.wmslocationid = wms.wmslocationid   ---- For Warehouse
			--and wms.WMSLOCATIONID = 'Store'
			and wms.WAXZONEID in ('MEZ1','MEZ2','VNA1','GOLD')
								--or wms.INVENTLOCATIONID = 'WH3PL')
	join Sandbox.fanzz.dim_item di
		on di.itemid = w.ITEMID
			and di.AXTeam = i.INVENTSTYLEID
			and di.Player = i.INVENTCOLORID
			and di.Color = i.CONFIGID
			and di.Size = i.INVENTSIZEID


group by 
di.DISTINCTPRODUCTVARIANT
,w.ITEMID
,i.INVENTSTYLEID 
,i.INVENTCOLORID 
,i.CONFIGID 
,i.INVENTSIZEID 
--drop table #dcinv
;




create unique clustered index dcinv on #dcinv
	(DISTINCTPRODUCTVARIANT
		,ITEMID
		,AXTeam
		,Player
		,Color
		,size);



set @progress = ( 'Current Mez Inventory: ' + cast(datediff(second,@starttime,getdate()) as varchar))
RAISERROR (@progress, 10, 1) WITH NOWAIT
set @starttime = getdate()

--select * from #DCInv where ITEMID = '100009091' and axteam = 'Alabama Crimson Tide -V1'
--select * from sandbox.fanzz.open_transfer where ITEMID = '100009091' and team = 'Alabama Crimson Tide -V1' order by createddatetime desc

---------------------------------------------------------------
-------Subtract Ecom Inventory from Live DC inventory----------
---------------------------------------------------------------

select
oh.DistinctProductVariant
,oh.PhysicalOnHand
into #Ecom_Res
from Sandbox.fanzz.OnHand oh
	where oh.InvntryEndDt is null
		and InventoryZone = 'Ecom'



update d
set Onhand = case when (d.Onhand - e.PhysicalOnHand) < 0 then 0 else (d.Onhand - e.PhysicalOnHand) end
from #DCInv d
	join #Ecom_Res e
		on d.DistinctProductVariant = e.DistinctProductVariant








---------------Make a copy of #DCinv ------Cursor decrements #DCinv
select * into #DCInv2 from #DCInv 


---------------Get Store Inventory--------------

select 
di.DistinctProductVariant
,w.ITEMID
,i.INVENTSTYLEID AXTeam
,i.INVENTCOLORID Player
,i.CONFIGID Color
,i.INVENTSIZEID size
,wms.INVENTLOCATIONID AXStore

,case when sum(w.AVAILPHYSICAL) < 0  then 0 else sum(w.AVAILPHYSICAL) end Onhand
--,sum(w.AVAILORDERED) AvailOrdered
into #StoreInv
from ods.dax.INVENTDIM i
	join ods.dax.WAXINVENTRESERVE w
		on w.INVENTDIMID = i.INVENTDIMID
			and i.WAXINVENTSTATUSID = 'GOOD'
			and w.WAXHIERARCHYLEVEL = 4
	join ods.dax.WMSLOCATION wms
		on i.INVENTLOCATIONID = wms.INVENTLOCATIONID  -- For Store
			and wms.WMSLOCATIONID = 'Store'
			and i.WMSLOCATIONID = wms.WMSLOCATIONID
	join Sandbox.fanzz.dim_item di
		on di.itemid = w.ITEMID
			and di.AXTeam = i.INVENTSTYLEID
			and di.Player = i.INVENTCOLORID
			and di.Color = i.CONFIGID
			and di.Size = i.INVENTSIZEID
group by 
di.DistinctProductVariant
,w.ITEMID
,i.INVENTSTYLEID 
,i.INVENTCOLORID 
,i.CONFIGID 
,i.INVENTSIZEID 
,wms.INVENTLOCATIONID

union

select
i.DistinctProductVariant
,i.ItemID
,i.AXTeam
,i.Player
,i.Color
,i.Size
,'Ecom'
,oh.PhysicalOnHand
from Sandbox.fanzz.dim_item i
	join Sandbox.fanzz.OnHand oh
		on i.DistinctProductVariant = oh.DistinctProductVariant
			and oh.InventoryZone = 'Ecom'
			and oh.InvntryEndDt is null

--select * from #storeinv where axstore = 'NMB01' and  itemid = '100046703'
--select * from ##need where axstore = 'CAN01' and axteam = 'Denver Broncos -V1' and itemid = '100020239'
--select distinct wms.WMSLOCATIONID  from ods.dax.WMSLOCATION wms


create unique clustered index storeinv on #StoreInv
	(DISTINCTPRODUCTVARIANT
		,ITEMID
		,AXTeam
		,Player
		,Color
		,size
		,axstore);


set @progress = ( 'Store Inventory: ' + cast(datediff(second,@starttime,getdate()) as varchar))
RAISERROR (@progress, 10, 1) WITH NOWAIT
set @starttime = getdate()


--------------------------------
---Store Inventory - at color level
--------------------------------
--select
--s.ItemID
--,s.AXTeam
--,s.Player
--,s.Color
--,s.AXStore
--,sum(OnHand) as OnHand

--into #StoreInv2
--	from #StoreInv s
--group by
--s.ItemID
--,s.AXTeam
--,s.Player
--,s.Color
--,s.AXStore


-------------------------------------------------------
----------Open Transfers - Soft Reservations-----------
--------------Updated by Python Script-----------------
-------------------------------------------------------

select

t.ToAddressName AXStore
,t.itemid
,t.team AXTeam
,t.Player
,t.Color
,t.Size
,sum(t.QtyTransfered - t.QtyRecieved) OpenTO
into #OpenTO
from Sandbox.fanzz.Open_Transfer t
	where t.createddatetime > getdate() - 60 --Assume anything older than 60 days probably wont be fufilled
group by
t.ToAddressName
,t.itemid
,t.team
,t.Player
,t.Color
,t.Size

create unique clustered index opento on #OpenTO
(axstore,itemid,axteam,player,color,size)

set @progress =  'Open Transfers: ' + cast(datediff(second,@starttime,getdate()) as varchar)
RAISERROR (@progress, 10, 1) WITH NOWAIT
set @starttime = getdate()



---------------------------------------------
--------Size Level Calculation---------------
---------------------------------------------
select 
* 
into #replen_level 
from Sandbox.fanzz.Replen_Level 
where LevelEndDt is null 
	and InvntryLevel > 0

create clustered index RL_IDX on #Replen_level
(axstore,Vendor,League,Division,Department,SizeScaleType)

create index RL_IDX2 on #replen_level
(itemid,axteam,player,color)


select 
* 
into #size_scale 
from Sandbox.fanzz.Size_Scale
where ScaleEndDt is null 

create clustered index SS_IDX on #Size_Scale
(axstore,Vendor,League,Division,Department,SizeScaleType)


select
a.ItemID
,a.AXTeam
,a.Player
,a.Color
,a.Invntrylevel
,a.AXStore
,a.size
,a.SizeValue
,a.SizeLevel
--,a.OnHand
--,case when a.SizeLevel - a.OnHand < 0 then 0 else a.SizeLevel - a.OnHand end Need
into #SL1
from
	(select
	r.ItemID
	,r.AXTeam
	,r.Player
	,r.Color
	,s.size
	,r.Invntrylevel
	,s.AXStore

	,case when so.itemid is not null then so.sizevalue else s.SizeValue end SizeValue
	,case when so.itemid is not null then round(so.sizevalue * r.InvntryLevel,0)
			when r.InvntryLevel >= 14 and round(r.InvntryLevel * s.SizeValue,0) < 1 then 1 else round(r.InvntryLevel * s.SizeValue,0) end SizeLevel --force a full size run for any item with a level greater than 14
	--,coalesce(st.OnHand,0) OnHand


	
	from #replen_level r
		join #Size_scale s
			
			on r.AXStore = s.AXStore
				and r.Vendor = s.Vendor
				and r.League = s.League
				and r.Division = s.Division
				and r.Department = S.Department
				and r.SizeScaleType = s.SizeScaleType
				and r.LevelEndDt is null
				and s.ScaleEndDt is null
				and r.InvntryLevel > 0
		left join Sandbox.fanzz.size_scale_override so
			on so.itemid = r.Itemid
			and so.size = s.Size)a

create unique clustered index SL1_IDX on #SL1
(axstore,itemid,axteam,player,color,size)

------------------------------------------------
---------Make sure all items are valid----------
------------------------------------------------
select
s.*
into #SL2
from #SL1 s
	join Sandbox.fanzz.dim_item i
		on i.itemid = s.itemid
		and i.axteam = s.axteam
		and i.player = s.player
		and i.color = s.color
		and i.size = s.size

--------------------------------------------
--------------Final Size_level Table--------
--------------------------------------------
select
s.*
,coalesce(st.OnHand,0) OnHand
,case when s.SizeLevel - coalesce(ST.OnHand,0) < 0 then 0 else s.SizeLevel - coalesce(st.OnHand,0) end Need
into #sizelevel
from #SL2 s
left join #StoreInv st
	on st.AXStore = s.AXStore
		and s.ItemID = st.ItemID
		and s.AXTeam = st.AXTeam
		and s.Player = st.Player
		and s.Color = st.Color
		and s.Size = st.Size;

--------------------------------------------------
---------------Remove Duplicate Records-----------
--------------------------------------------------
with x as   (select  *,rn = row_number()
            over(PARTITION BY axstore,itemid,axteam,player,color,size order by axstore desc)
            from #Sizelevel)

delete from x
where rn > 1
;



create unique clustered index SizeLevel on #SizeLevel
	(ITEMID
		,AXTeam
		,Player
		,Color
		,size
		,axstore);

--select * from #size_level
-------------------------------------------
-------------clean up temp tables----------
-------------------------------------------
--drop table #SL1
IF OBJECT_ID('tempdb..#SL1') IS NOT null
BEGIN
DROP TABLE #SL1
END;

IF OBJECT_ID('tempdb..#SL2') IS NOT null
BEGIN
DROP TABLE #SL2
END;

IF OBJECT_ID('tempdb..#Replen_Level') IS NOT null
BEGIN
DROP TABLE #Replen_Level
END;

IF OBJECT_ID('tempdb..#Size_Scale') IS NOT null
BEGIN
DROP TABLE #Size_Scale
END;


set @progress = ( 'Size Level: ' + cast(datediff(second,@starttime,getdate()) as varchar))
RAISERROR (@progress, 10, 1) WITH NOWAIT
set @starttime = getdate()
--l from #sizelevel 
--drop table #SIzelevel where need > 0
--select * from ##need where itemid = '100016455' and axteam = 'Philadelphia Eagles -V1' and player = 'Murray Demarco' and color = 'Green' and axstore = 'PAB01'
-- select * from sandbox.fanzz.dim_item where itemid = '100080261' and axteam = 'Seattle Seahawks -V1'
--select * from sandbox.fanzz.replen_level where itemid = '100075230' and axteam = 'Seattle Seahawks -V1' and levelenddt is null
--select * from Sandbox.fanzz.Size_Scale_Generic where Scale_type = 'Alpha 1'
--------------------------------------------------------------
------------------Turn Levels of 4 into a 1-2-1---------------
--------------------------------------------------------------
--select * from #Sizelevel
update #SizeLevel
set SizeLevel = case when Size = 'XS' then 0
					When size = 'Small' then 0
					when size = 'Medium' then 1
					when size = 'Large' then 1
					when size = 'XL' then 1
					when size = '2xl' then 1
					else SizeLevel end
	,Need = case when Size = 'XS' then 0
					When size = 'Small' then 0
					when size = 'Medium' then 1
					when size = 'Large' then 1
					when size = 'XL' then 1
					when size = '2xl' then 1
					else Need end - OnHand
	where InvntryLevel > 0 and  InvntryLevel <= 4
	--and division not like '%Women%';

--select * from Sandbox.fanzz.Replen_Level where itemid = '100081298' and LevelEndDt is null and AXStore = 'NMB04'
--select from Sandbox.fanzz.Size_Scale where Vendor = 'Adidas' and League = 'NBA' and Division = 'Mens Apparel' and Department = 'Tees' and SizeScaleType = 'Alpha 1' 
--select axteam,size, sum(sizelevel) from ##need where  itemid = '100050908' group by size, axteam
--select * from sandbox.fanzz.replen_level where itemid = '100050908' and axteam = 'boston red sox -v1' and levelenddt is null and invntrylevel > 0
-----------------------------------------------------------------------------
-----------Turn Levels of 6 in Headwear to  into a 1-1-1-1-1-1---------------
-----------------------------------------------------------------------------
update #SizeLevel
set SizeLevel = case when Size = '7' then 1
					When size = '7.125' then 1
					when size = '7.25' then 1
					when size = '7.375' then 1
					when size = '7.5' then 1
					when size = '7.625' then 1
					when size = '7.75' then 0
					when size = '7.875' then 0
					when size = '8' then 0
					else SizeLevel end
	,Need = case when Size = '7' then 1
					When size = '7.125' then 1
					when size = '7.25' then 1
					when size = '7.375' then 1
					when size = '7.5' then 1
					when size = '7.625' then 1
					when size = '7.75' then 0
					when size = '7.875' then 0
					when size = '8' then 0
					else SizeLevel end - OnHand
	where InvntryLevel > 0 and  InvntryLevel <= 6;
	
update #SizeLevel --Fix negatives
	set need = 0 
		where need < 0;


set @progress = ( 'Forced Sizes: ' + cast(datediff(second,@starttime,getdate()) as varchar))
set @starttime = getdate()

----------------------------------------------------------------
---------------Calculate Need - Less Open Transfers-------------
--------------Assumes that all transfers will be fufilled-------
----------------------------------------------------------------
--drop table ##need
select 
l.Itemid
,l.AXTeam
,l.Player
,l.Color
,l.Size
,l.InvntryLevel
,l.AXStore
,l.SizeValue
,l.SizeLevel
,l.OnHand
,case when (l.Need - coalesce(t.OpenTO,0)) < 0 then 0 else (l.Need - coalesce(t.OpenTO,0)) end Need -- Account for Open Transfers - Make sure python script has kicked off first
--,t.opento
,i.department
into ##need
from #SizeLevel l

	join #DimItem i
			on i.ItemID = l.Itemid
				and i.AXTeam = l.AXTeam
				and i.Player = l.Player
				and i.Color = l.Color
				and i.Size = l.Size ---- Make sure that the sizes are valid sizes

	left join #OpenTO t

		on l.AXStore = t.AXStore
			and l.Itemid = t.itemid
			and l.AXTeam = coalesce(t.AXTeam,'') --- WHY DOESN'T BI SERVER USE NULLS?!?!?
			and l.Player = coalesce(t.Player,'')
			and l.Color = coalesce(t.Color,'')
			and l.Size = coalesce(t.Size,'')
			--where l.itemid = '100076770' and l.axstore = 'UTB04' and l.axteam = 'LA Angels -V1' order by size

create clustered index Need_IDX on ##Need
(itemid,axteam,player,color,size,axstore);

--select * from ##need where Itemid = '100078591' and axteam = 'Green Bay Packers -V1' and color = 'Green' and need > 0
set @progress = ( 'Need: ' + cast(datediff(second,@starttime,getdate()) as varchar))
RAISERROR (@progress, 10, 1) WITH NOWAIT
set @starttime = getdate()




----------------------------------------------
----------Begin Store Priority Logic----------
----------------------------------------------
--drop table #date
select 
datevalue 
into #Date
from dw.fanzz.Dim_RetailDate 
	where datevalue > cast(getdate() -95 as date)
		and datevalue <= cast(getdate() as date)

create index date on #date
(datevalue)

select
axstore
,storekey
into #Dim_store
from dw.fanzz.dim_store where ActiveStore = 'Active'

create index date on #dim_store
(axstore,storekey)

select
* 
into #onhand
from sandbox.fanzz.onhand
where inventoryzone = 'Store'
and physicalonhand > 0

create unique clustered index onhand_idx on #onhand
(distinctproductvariant,storekey,invntrystartdt,invntryenddt)


------------------Avlbl Days------------------
--drop table #h_inv
select
cast(dt.DateValue as date) Date
,i.ItemID
,i.AXTeam
,i.Player
,i.Color
,i.department
,ds.AXStore
,sum(oh.PhysicalOnHand) OnHand
into #h_inv
from #DimItem i
	join #onhand oh
		on i.DistinctProductVariant = oh.DistinctProductVariant
		--and oh.inventoryzone = 'Store'
		--and oh.PhysicalOnHand > 0
	join #date dt
		on cast(dt.DateValue as date) between oh.InvntryStartDt and coalesce(InvntryEndDt, cast(getdate() as date))
			and cast(dt.Datevalue as date) >= cast(getdate() - 90 as date) --Limits Avlbl Days
	join #Dim_Store ds
		on ds.StoreKey = oh.StoreKey
--where i.ItemID = '100001300' and i.AXTeam = 'NY Yankees -V1' and i.Color = 'Navy' --and ds.AXStore = 'TXB16'
group by 
cast(dt.DateValue as date)
,i.ItemID
,i.AXTeam
,i.Player
,i.Color
,i.department
,ds.AXStore

CREATE unique clustered index inv_idx on #h_inv
(itemid,axteam,player,color,axstore,date)




set @progress = ( 'Hierarchy Avaliable Days: ' + cast(datediff(second,@starttime,getdate()) as varchar))
RAISERROR (@progress, 10, 1) WITH NOWAIT
set @starttime = getdate()
---------------------------Sales----------------------
select
i.ItemID
,i.AXTeam
,i.Player
,i.Color
,i.Department
,ds.AXStore
,sum(s.Quantity) Units_Sold
into #h_Sales
from dw.fanzz.dim_item i
		left join dw.fanzz.Fact_Sales s
		on i.ItemKey = s.ItemKey
			and s.SalesDate between cast(getdate() - 90 as date) and cast(getdate() as date)
			--and i.itemid in (select itemid from sandbox.fanzz.Replen_level where Levelenddt is null)
			and s.Quantity > 0
	join dw.fanzz.Dim_Store ds
		on s.StoreKey = ds.StoreKey

			and ds.AXStore is not null
	--where i.ItemID = '100001300' and i.AXTeam = 'NY Yankees -V1' and i.Color = 'Navy'-- and ds.AXStore = 'TXB16'
group by
i.ItemID
,i.AXTeam
,i.Player
,i.Color
,i.Department
,ds.AXStore

CREATE unique clustered index sls_idx on #h_Sales
(itemid,axteam,player,color,axstore)

set @progress = ( 'Hierarchy Sales: ' + cast(datediff(second,@starttime,getdate()) as varchar))
RAISERROR (@progress, 10, 1) WITH NOWAIT
set @starttime = getdate()


----------- Level 1 - SKU ARS -------------
Select
a.ItemID
,a.AXTeam
,a.Player
,a.Color
,a.AXStore
,b.Units_Sold
,count(a.OnHand) AvlblDays
,coalesce(round(b.Units_Sold / nullif(count(a.OnHand),0),4),0)  ARS
into #Level1
	from
		#h_inv
		a
	Left Join
		#h_Sales b
			on	a.ItemID = b.ItemID
				and a.AXStore = b.AXStore
				and a.AXTeam = b.AXTeam
				and a.Player = b.Player
				and a.Color = b.Color

	--where a.ItemID = '100001300' and a.AXTeam = 'NY Yankees -V1' and a.Color = 'Navy' 
group by
a.ItemID
,a.AXTeam
,a.Player
,a.Color
,a.AXStore
,b.Units_Sold


create unique clustered index level1 on #level1 
	(ItemID
		,AXTeam
		,Player
		,Color
		,AXStore);


set @progress = ( 'Level 1 Hierarchy: ' + cast(datediff(second,@starttime,getdate()) as varchar))
RAISERROR (@progress, 10, 1) WITH NOWAIT
set @starttime = getdate()
--drop table #level2
--drop table #level3


--Declare 21 int
--Set 21 = 21

----------- Level 2 - Team/Category ARS -------------
Select
a.AXTeam
,a.AXStore
,a.Department
,b.Units_Sold
,count(a.OnHand) AvlblDays
,coalesce(round(b.Units_Sold / nullif(count(a.OnHand),0),4),0)  ARS
into #Level2
	from
		(
		select
		oh.Date
		,oh.AXTeam
		,oh.Department
		,oh.AXStore
		,sum(oh.onhand) OnHand
			from #h_inv oh
		group by 
		oh.date
		,oh.AXTeam
		,oh.Department
		,oh.AXStore

		)a
	Left Join
		(
		select
		s.AXTeam
		,s.Department
		,s.AXStore
		,sum(s.Units_Sold) Units_Sold
		from #h_Sales s
		group by
		s.AXTeam
		,s.Department
		,s.AXStore
		)b
			on	a.AXStore = b.AXStore
				and a.AXTeam = b.AXTeam
				and a.Department = b.Department
				
	--where a.ItemID = '100001300' and a.AXTeam = 'NY Yankees -V1' and a.Color = 'Navy' and a.AXStore = 'TXB16'
group by
a.AXTeam
,a.AXStore
,a.Department
,b.Units_Sold

;
create unique clustered index Level2 on #Level2
	(AXTeam
	,AXStore
	,Department);

set @progress = ( 'Level 2 Hierarchy: ' + cast(datediff(second,@starttime,getdate()) as varchar))
RAISERROR (@progress, 10, 1) WITH NOWAIT
set @starttime = getdate()
--Declare 21 int
--Set 21 = 21

----------- Level 3 - Store ARS -------------
--drop table #level3

Select
a.AXStore
,a.axteam
,b.Units_Sold
,count(a.OnHand) AvlblDays
,coalesce(round(b.Units_Sold / nullif(count(a.OnHand),0),4),0)  ARS
into #Level3
	from
		(
		select
		oh.Date
		,oh.AXStore
		,oh.axteam
		,sum(oh.OnHand) OnHand
			from #h_inv oh
		group by 
		oh.Date
		,oh.AXStore
		,oh.axteam

		)a
	Left Join
		(
		select
		s.AXStore
		,s.axteam
		,sum(s.Units_Sold) Units_Sold
			from #h_Sales s
		group by
		s.AXStore
		,s.axteam
		)b
			on	a.AXStore = b.AXStore
				and a.axteam = b.axteam
				
				
	--where a.ItemID = '100001300' and a.AXTeam = 'NY Yankees -V1' and a.Color = 'Navy' and a.AXStore = 'TXB16'
group by
a.AXStore
,b.Units_Sold
,a.AXTeam

;

create unique clustered index Level3 on #Level3
	(AXStore,AXteam);

set @progress = ( 'Level 3 Hierarchy: ' + cast(datediff(second,@starttime,getdate()) as varchar))
RAISERROR (@progress, 10, 1) WITH NOWAIT
set @starttime = getdate()
----------------------------------------------------------------------
----Need Ranked for Cursor - Which store gets priority in scarcity----
----------------------------------------------------------------------
--select * from ##needranked where itemid = '100080679'
--drop table ##needranked

Select distinct
i.itemid
,i.AXTeam
,i.Player
,i.Color
,i.Department	
into #DI
from
#DimItem i;

create unique clustered index DI_IDX on #DI
(itemid,axteam,player,color);
--drop table ##needranked

select 
n.ItemID
,n.AXTeam
,n.Player
,n.Color
,n.Size
,n.AXStore
,n.Need
,n.department
,coalesce(a.ARS,0) SKU
,coalesce(b.ARS,0) TeamDept
,coalesce(c.ARS,0) Team
,case --when n.axstore = 'Ecom' then -1 --Ecom Reserves First
		when n.axstore in ('NMB05','ORB02','UTB01') then 0 --Football only stores reserve second
		else row_number() OVER(partition by n.itemid, n.axteam,n.player,n.color, n.size ORDER BY coalesce(a.ARS,0) desc,coalesce(b.ARS,0) desc,coalesce(c.ARS,0) desc) end Rnk  --Force Ecom to Reserve First
into ##needranked
from ##need n
	Left join #Level1 a
		on n.ItemID = a.ItemID
			and n.AXStore = a.AXStore
			and n.AXTeam = a.AXTeam
			and n.Player = a.Player
			and n.Color = a.Color
			and n.need > 0
	Left join #Level2 b
		on n.AXStore = b.AXStore
			and n.AXTeam = b.AXTeam
			and n.Department = b.Department
	left join #Level3 c
		on n.AXStore = c.AXStore
		 and n.axteam = c.axteam
		


--order by 1,2,3,4,5,11 
;

create  clustered index needranked on ##needranked
	(ItemID
	,AXTeam
	,Player
	,Color
	,Size
	,AXStore);

set @progress =( 'Need Ranked: ' + cast(datediff(second,@starttime,getdate()) as varchar))
RAISERROR (@progress, 10, 1) WITH NOWAIT
set @starttime = getdate()

--select * from ##needranked where Itemid = '100020239' and axteam = 'Denver Broncos -v1' and axstore = 'Can01' 

--select * from sandbox.fanzz.replen_level_transfers where ToWhs = 'Ecom'
--order by rnk asc

--select * from #SizeLevel where itemid = 100080679 and axteam = 'San Francisco Giants -V1' and AXStore = 'CAN01'
--select * from Sandbox.fanzz.dim_item where itemid = '100080679'

delete from sandbox.fanzz.Replen_Level_Transfers
----------------------------------------------------------
---------------Allocation Cursor--------------------------
----------------------------------------------------------

declare @ItemID int
declare @AXTeam Varchar(100)
declare @Player Varchar(100)
declare @Color	Varchar(100)
declare @Size Varchar(100)
declare @Need int
declare @DCOnHand int
declare @DistinctProductVariant bigint
declare @Send int
declare @AXStore varchar(10)
declare @Total int
declare @Row_num int
declare @Rows int
declare Outer_Cursor cursor for

select 
d.DistinctProductVariant
,d.ItemID
,d.AXTeam
,d.Player
,d.Color
,d.Size
,d.OnHand
,row_number() over(order by d.itemid,d.axteam,d.player,d.color,d.size)
,count(*) over(partition by 1)
from #DCInv d
	join
		(
		select distinct
		n.ItemID
		,n.AXTeam
		,n.Player
		,n.Color
		,n.Size
		from ##need n
			where n.Need > 0
		)a ---Limit query to only items where there is a need
			on d.ItemID = a.ItemID
				and d.AXTeam = a.AXTeam
				and d.Player = a.Player
				and d.Color	 = a.Color
				and d.Size = a.Size
				and d.OnHand > 0
				 --and d.Itemid = '100009091' and d.axteam = 'Alabama Crimson Tide -V1'
			order by 2,3,4,5,6

			--select * from #DCInv where ITEMID = '100009091' and axteam	='Alabama Crimson Tide -V1'
	
open Outer_Cursor
fetch next from Outer_Cursor into 
	@DistinctProductvariant,@ItemId,@AXTeam,@Player,@Color,@Size,@DCOnHand,@Row_num,@Rows

	---------Begin outer loop-------------
	While @@FETCH_STATUS = 0
	begin

	set @progress =( 'Cursor Progress: ' + cast(@row_num as varchar) + ' of ' + cast(@Rows as varchar)) --print progress
	RAISERROR (@progress, 10, 1) WITH NOWAIT

		declare Inner_Cursor cursor for
			select
			AXStore
			,n.Need
			from ##needranked n
			where n.ItemID = @ItemID
				and n.AXTeam = @AXTeam
				and n.Player = @Player
				and n.Color = @Color
				and n.Size = @Size
				and  AXstore <> 'Ecom' ---------------------------------------Remove me ------------------------------------------------
				and axstore <> 'ECM01'
			order by rnk asc ---- Higher ranked item / store combos get priority for allocation

		open Inner_Cursor
		fetch next from Inner_Cursor into
			@AXStore,@Need

		---------Begin inner loop-------------
		While @DCOnHand > 0 and @@FETCH_STATUS = 0
			begin
				if @DCOnHand >= @Need
					begin
						insert into sandbox.fanzz.replen_level_transfers
							select 'WHS01',@AXStore,@ItemID,@AXTeam,@Player,@Color,@Size,@Need --- Create transfer in table

						set @DCOnHand = @DCOnHand - @Need --Adjust for quantity reserved

						update #DCInv  -- Update DCInv table  --- Mostly for QA
							set OnHand = @DCOnHand
								where DistinctProductVariant = @DistinctProductVariant
						set @Total = @Total + @Need
					end
			
				else  --when there is less on hand than needed
					begin
						set @need = @DCOnHand --Send what is avaliable

						insert into sandbox.fanzz.replen_level_transfers --Create transfer int table
							select 'WHS01',@AXStore,@ItemID,@AXTeam,@Player,@Color,@Size,@Need 

						set @DCOnHand = 0 --Zero out the remaining inventory
					
						update #DCInv  -- Update DCInv table  --- Mostly for QA
							set OnHand = @DCOnHand
								where DistinctProductVariant = @DistinctProductVariant

						set @Total = @Total + @Need
					end
			Print 'Total: '  + cast( @Total as varchar(10))
			fetch next from Inner_Cursor into
				@AXStore,@Need
			End
			close Inner_Cursor
			deallocate Inner_Cursor
			-----------End inner loop---------

	fetch next from Outer_Cursor into 
		@DistinctProductvariant,@ItemId,@AXTeam,@Player,@Color,@Size,@DCOnHand
	end ---------------End outer loop-------------
close Outer_Cursor
deallocate Outer_Cursor

set @progress = ( 'Allocation Cursor: ' + cast(datediff(second,@starttime,getdate()) as varchar))
RAISERROR (@progress, 10, 1) WITH NOWAIT
set @starttime = getdate()
----------------------------------------------------------
----------------Set Case Pack Quantities------------------
----------------------------------------------------------
update  t
set t.qty = floor(t.qty/c.casepack) * c.casepack --round down to the nearest casepack
--select * , floor(t.qty/c.casepack) * c.casepack
from sandbox.fanzz.replen_level_transfers t
	join sandbox.fanzz.level_casepack c
		on t.itemid = c.itemid
where t.itemid in (select itemid from sandbox.fanzz.Level_Casepack)
;

delete from sandbox.fanzz.replen_level_transfers where qty = 0  -- delete casepacks that have been rounded to 0

;

set @progress = ( 'Case Packs: ' + cast(datediff(second,@starttime,getdate()) as varchar))
RAISERROR (@progress, 10, 1) WITH NOWAIT
set @starttime = getdate()
-------------------------------------------------------------
-------------Remove any Dupes from Replen_Old----------------
------------------Keeps most recent record-------------------
-------------------------------------------------------------
;
with x as   (select  *,rn = row_number()
            over(PARTITION BY fromWHS,towhs,itemid,axteam,player,color,size order by uploaded desc)
            from sandbox.fanzz.Replen_old)

delete from x
where rn > 1
;



---------------------------------------------------------------
--------------Get pool of items new to stores------------------
---------------------------------------------------------------
select
t.axstore
,t.itemid
,t.axteam
,t.player
,t.color
,t.Qty
,coalesce(oh.DaysInStore,0) DaysInStore
into #New_items
from
		(select
		t.ToWhs AXstore
		,t.ItemID
		,t.AXTeam
		,t.Player
		,t.Color
		,sum(t.qty) Qty

		from Sandbox.fanzz.replen_level_transfers t
			where t.towhs <> 'UTX01'
				and t.size <> ''
		group by
		t.ToWhs 
		,t.ItemID
		,t.AXTeam
		,t.Player
		,t.Color) t

		left join 

		(select
		ds.AXStore
		,i.ItemID
		,i.AXTeam
		,i.Player
		,i.Color
		,count(distinct d.Date) DaysInStore
		from Sandbox.fanzz.dim_item i	
			join Sandbox.fanzz.OnHand oh
				on oh.DistinctProductVariant = i.DistinctProductVariant
					and oh.OnHand > 0
			join dw.fanzz.dim_date d
				on d.Date between oh.InvntryStartDt and coalesce(oh.InvntryEndDt, cast(getdate() as date))
				and d.date > cast(getdate() - 30 as date) ----Style has not been in the store for at least 30 days prior to today
			join Sandbox.fanzz.dim_store ds
				on ds.StoreKey = oh.StoreKey
				where exists (select * from Sandbox.fanzz.Replen_Level_Transfers t
								where t.ItemID = i.ItemID
									and t.AXTeam = i.AXTeam
									and t.Player = i.Player
									and t.Color = i.Color
									and t.ToWhs = ds.AXStore)
		group by
		ds.AXStore
		,i.ItemID
		,i.AXTeam
		,i.Player
		,i.Color) oh
				on oh.itemid = t.itemid
				and oh.axteam = t.axteam
				and oh.player = t.player
				and oh.color = t.color
				and oh.axstore = t.axstore
		where coalesce(oh.daysinstore,0) = 0;

set @progress = ( 'Pool of items new to stores: ' + cast(datediff(second,@starttime,getdate()) as varchar))
RAISERROR (@progress, 10, 1) WITH NOWAIT
set @starttime = getdate()
-------------------------------------------------------------------------
----------------Identify Broken Size Run Transfers-----------------------
-------------------------------------------------------------------------

select
t.towhs
,t.ItemID
,t.AXTeam
,t.Player
,t.Color
,sum(t.qty) Qty
,n.DaysInStore
,i.Scale_type
,c.Core_Count
,sum(g.coreflag)Core_Size_Count
,count(distinct t.Size) TTL_Size_Count
into #Broken_Size_Runs
from sandbox.fanzz.replen_level_transfers t
	join #New_items n
		on t.itemid = n.itemid
		and t.axteam = n.axteam
		and t.player = n.player
		and t.color = n.color
		and t.towhs = n.axstore
		--and t.itemid = '100081773'
	join Sandbox.fanzz.Size_Scale_Item i
		on i.itemid = t.ItemID
		and i.axteam = t.AXTeam
		and i.player = t.Player
		and i.color = t.Color
	join Sandbox.fanzz.Size_Scale_Generic g
		on g.Scale_type = i.Scale_type
			and g.Size = t.Size
	join (select
			scale_type
			,sum(coreflag) Core_Count
			from Sandbox.fanzz.Size_Scale_Generic
			group by Scale_type) c
				on c.Scale_type = g.Scale_type

	join (select distinct
			itemid
			,buyergroup
			from Sandbox.fanzz.dim_item i
			where i.BuyerGroup <> 'Impulse') b
			on t.ItemID = b.itemid
	--where i.Scale_type is null
	--where  t.itemid = '100050846' and t.axteam ='UCLA Bruins -V1' and t.player = ''
group by
t.ToWhs
,t.ItemID
,t.AXTeam
,t.Player
,t.Color
,n.DaysInStore
,i.Scale_type
,c.Core_Count

having sum(g.coreflag) <= c.Core_Count - 1
	and count(distinct t.Size) < c.Core_Count
		order by 1,2,3,4,5;

set @progress = ( 'Identify broken size runs: ' + cast(datediff(second,@starttime,getdate()) as varchar))
RAISERROR (@progress, 10, 1) WITH NOWAIT
set @starttime = getdate()
---------------------------------------------------------------
----------Delete Broken Size Run Transfers---------------------
---------------------------------------------------------------

delete t
--select *
from Sandbox.fanzz.Replen_Level_Transfers t
	join #Broken_Size_Runs b
		on t.ToWhs = b.ToWhs
		and t.ItemID = b.ItemID
		and t.AXTeam = b.AXTeam
		and t.Player = b.Player
		and t.Color = b.Color
		where not exists (select * from Sandbox.fanzz.Broken_Size_Run_Exclude e
							where 1=1
								and e.itemid = t.itemid
								and e.axteam = t.axteam
								and e.player = t.player
								and e.color = t.color
								and coalesce(e.expire,cast(getdate() as date)) <= cast(getdate() as date));

set @progress = ( 'Delete Broken Size Runs: ' + cast(datediff(second,@starttime,getdate()) as varchar))
RAISERROR (@progress, 10, 1) WITH NOWAIT
set @starttime = getdate()

declare @TTL as int
set @ttl = (select sum(qty) from sandbox.fanzz.replen_level_transfers)
print '--------------------------'
print 'Total Units' 
print @ttl
print '--------------------------'

---------------------------------------------------
-----------Pull data for transfers-----------------
---------------------------------------------------
select * from
(select 
 t.FromWhs
 ,t.ToWhs
 ,t.ItemID
 ,t.AXTeam
 ,t.Player
 ,t.Color
 ,t.Size
 ,t.QTY
 --,t.ttl
from
	(select
	 t.FromWhs
	 ,t.ToWhs
	 ,t.ItemID
	 ,t.AXTeam
	 ,t.Player
	 ,t.Color
	 ,t.Size
	 ,t.QTY
	 ,sum(t.qty) over(partition by t.ToWhs) Ttl
 
	 from sandbox.fanzz.replen_level_transfers t

	
	 group by

	  t.FromWhs
	 ,t.ToWhs
	 ,t.ItemID
	 ,t.AXTeam
	 ,t.Player
	 ,t.Color
	 ,t.Size
	 ,t.QTY)t
		where 1=1
		 and t.ToWhs in
			(
			select
			ds.AXStore
			from dw.fanzz.Dim_Store ds
				join Sandbox.fanzz.Level_Transfer_Day t
					on ds.Division = t.Division
				join dw.fanzz.Dim_Date dt
					on t.day = dt.DayOfWeek
					and dt.Date = cast(getdate() as date))
					

					or (ttl >= 300
						and t.ToWhs not in
						(select
						ds.AXStore
						from dw.fanzz.Dim_Store ds
							join Sandbox.fanzz.Level_Transfer_Day t
								on ds.Division = t.Division
							join dw.fanzz.Dim_Date dt
								on t.day = dt.DayOfWeek + 1
								and dt.Date = cast(getdate() as date)))
							and ToWhs not in ('UTV04','COB06','TXB06','UTT01','TXB02','COB05')
								--or t.itemid = '100051050' --------temporary
						--order by 1,2,3,4,5,6,7 
					

union

	select -------Pull venue replen based on venue schedule
	t.*
	from sandbox.fanzz.replen_level_transfers t
		join Sandbox.Fanzz.Level_Venue_Transfer	v
			on v.AXstore = t.ToWhs
				and v.Transfer_Dt = cast(getdate() as date)


union

select
a.FromWhs
,a.ToWhs
,a.ItemID
,a.AXTeam
,a.Player
,a.Color
,a.Size
,a.QTY
from
	(select
	o.FromWhs
	,o.ToWhs
	,o.ItemID
	,o.AXTeam
	,o.Player
	,o.Color
	,o.Size
	,o.QTY
	,o.Uploaded
	,max(o.Uploaded) Max_Upload

	from Sandbox.fanzz.Replen_Old o
	where o.ToWhs in
		(select
		ds.AXStore
		from dw.fanzz.Dim_Store ds
			join Sandbox.fanzz.Level_Transfer_Day t
				on ds.Division = t.Division
			join dw.fanzz.Dim_Date dt
				on t.day = dt.DayOfWeek 
				and dt.Date = cast(getdate() as date))
	group by
	o.FromWhs
	,o.ToWhs
	,o.ItemID
	,o.AXTeam
	,o.Player
	,o.Color
	,o.Size
	,o.QTY
	,o.Uploaded)a

			where a.Max_Upload >= getdate() - 7
				and a.Uploaded = a.Max_Upload
	
union 

select ---Pull low capacity stores according to schedule located in Sandbox.fanzz.Low_capacity_stores
 t.FromWhs
 ,t.ToWhs
 ,t.ItemID
 ,t.AXTeam
 ,t.Player
 ,t.Color
 ,t.Size
 ,t.QTY
from sandbox.fanzz.replen_level_transfers t
			join Sandbox.fanzz.Low_capacity_stores s
				on t.ToWhs = s.AXStore
				and s.day = (select d.DayOfWeek from dw.fanzz.Dim_Date d where date = cast(getdate() as date) ) 
)a 

where ToWhs <> 'Ecom'
and ToWhs not in ('UTV05','COB06','TXB06','UTT01','TXB02','COB05','MOB02','OHB01') --Disable venues for out of season
--and ItemID not in ('100014674','100009783','100036725','100038339','100018771') -- no blankets


order by sum(qty)over(partition by towhs),1,2,3,4,5,6,7 ;

print 'Total time: ' + cast(datediff(second,@begin,getdate()) as varchar)

----select * from ##need where AXStore = 'utx01' and itemid = '100079093'

----select * from sandbox.fanzz.onhand_results
--;
--select 
--t.ToWhs
--,t.ItemID
--,t.AXTeam
--,t.Player
--,t.Color
--,t.Size
--,t.QTY
--from sandbox.fanzz.replen_level_transfers t
--	where not exists
--			(select
--			i.ItemID
--			,i.AXTeam
--			,i.Player
--			,i.Color
--			,ds.AXStore
--			,sum(PhysicalOnHand)


--			from Sandbox.fanzz.dim_item i
--				join Sandbox.fanzz.OnHand  oh with (nolock)
--					on i.DistinctProductVariant = oh.DistinctProductVariant
--					and oh.invntryenddt is null

--				join dw.fanzz.dim_store ds
--					on oh.StoreKey = ds.StoreKey
--						and t.ItemID = i.ItemID
--						and t.AXTeam = i.AXTeam
--						and t.Player = t.Player
--						and t.Color  = t.Color
--						and t.ToWhs = ds.AXStore
--			group by
--			i.ItemID
--			,i.AXTeam
--			,i.Player
--			,i.Color
--			,ds.AXStore)
--			AND t.ToWhs <> 'Ecom'
--			order by 1,2,3,4,5

--;



--select
--i.ItemID
--,i.AXTeam
--,i.Player
--,i.Color
--,ds.AXStore
--,sum(PhysicalOnHand)


--from Sandbox.fanzz.dim_item i
--	join Sandbox.fanzz.OnHand oh
--		on i.DistinctProductVariant = oh.DistinctProductVariant
--		and oh.invntryenddt is null

--	join dw.fanzz.dim_store ds
--		on oh.StoreKey = ds.StoreKey

--	and AXStore = 'CAN01' and itemid = '100080753' and axteam = 'Oakland As -V1' and player = '' and color = 'Green'
--group by
--i.ItemID
--,i.AXTeam
--,i.Player
--,i.Color
--,ds.AXStore

--select sum(qty) from sandbox.fanzz.replen_level_transfers

--select * from Sandbox.fanzz.Replen_Level where AXStore = 'CAN01' and itemid = '100081113' and axteam = 'Oakland As -V1' and player = '' and color = 'Green'

--select * from ##need where AXStore = 'CAN01' and itemid = '100044187' and axteam = 'San Francisco 49ers -v1' and player = '' and color = 'Black'


--select * from #DCInv where itemid = '100044187' and axteam = 'San Francisco 49ers -v1'

--select * from Sandbox.fanzz.onhand where DistinctProductVariant = '5637591204' and InvntryEndDt is null

--select * from ##needranked where AXStore = 'CAN01'


--select size, sum(qty) from sandbox.fanzz.replen_level_transfers where  itemid = '100044187' and axteam = 'San Francisco 49ers -v1' group by size


--select 
--i.ItemID
--,i.AXTeam
--,i.Player
--,i.Color
--,sum(t.QTY)

-- from sandbox.fanzz.replen_level_transfers t
--	join Sandbox.fanzz.dim_item i
--		 on t.itemid = i.ItemID
--		and t.AXTeam = i.AXTeam
--		and t.player = i.Player
--		and t.color = i.Color
--		and t.size = i.Size

--		where not exists(
--						select * from Sandbox.fanzz.OnHand oh
--							where i.DistinctProductVariant = oh.DistinctProductVariant
--							and oh.InventoryZone = 'MEZ'
--							and oh.InvntryEndDt is null
--							and oh.PhysicalOnHand > 0)
--group by
--i.ItemID
--,i.AXTeam
--,i.Player
--,i.Color


--select * from #DCInv where itemid = '100009091' and axteam = 'Alabama Crimson Tide -V1' and size = 'med/large'


--select
--i.itemid
--,i.axteam
--,i.player
--,i.color
--,i.size
--,oh.InventoryZone
--,oh.physicalonhand


--from sandbox.fanzz.dim_item i
--	join sandbox.fanzz.onhand oh
--		on oh.DistinctProductVariant = i.DistinctProductVariant
--			and oh.InvntryEndDt is null
--			--and oh.InventoryZone = 'mez' 
--			and Itemid = '100014674' --and AXTeam = 'Duke Blue Devils -V1' 
--			and axteam = 'Seattle Seahawks -v1'


--order by 1,2,3,4,5,6


--select * from #level1 where itemid = '100016455' and player = 'Kaepernick Colin' and levelenddt is null

--select * from sandbox.fanzz.open_transfer where itemid = '100016456' order by createddatetime desc
--select 

--*

--from ##need n where not exists( select * from (
--	select 
--	ds.AXStore
--	,i.ItemID
--	,i.AXTeam
--	,i.Player
--	,i.Color
--	,sum(oh.physicalonhand) ONHAND
	

--	from sandbox.fanzz.dim_item i
--		join sandbox.fanzz.onhand oh
--			on i.distinctproductvariant = oh.distinctproductvariant
--			and oh.InventoryZone = 'Store'
--			and oh.invntryenddt is null
--				--and oh.physicalonhand > 0
--		join dw.fanzz.dim_store ds
--			on ds.StoreKey = oh.StoreKey
--				and ds.activestore = 'Active'
--			--and ds.axstore = 'UTB02'

--		and exists (select * from ##need n
--						where n.itemid = i.itemid
--							and n.axteam = i.axteam
--							and n.player = i.player
--							and n.color = i.player
--							and n.size = i.size
--							and n.invntrylevel > 0)
				

--	group by
--	ds.AXStore
--	,i.ItemID
--	,i.AXTeam
--	,i.Player
--	,i.Color)a
--	where a.axstore = n.axstore
--		and a.itemid = n.itemid
--		and a.player = n.player
--		and a.color = n.color)
--		and n.invntrylevel > 0
--		and n.axstore <> 'Ecom'
--			and n.itemid = '100003397'
--					and n.axteam = 'NY Yankees -V1'
--					and n.axstore = 'UTB06'



