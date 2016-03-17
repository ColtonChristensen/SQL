select 
a.ParentASIN
,a.ASIN
,i.itemid
,i.AXTeam
,i.Player
,i.Color
,i.Size
,a.Title
--,a.date
from sandbox.fanzz.amazon a
				join (select ASIN, max(date) Date from sandbox.fanzz.amazon group by ASIN) aa
					on aa.ASIN = a.ASIN
				join sandbox.fanzz.dim_item i
					on i.retailvariantid = a.retailvariantid
						and a.date = aa.date
					where itemid = '100083648'
order by itemid,axteam,player,color,channel

