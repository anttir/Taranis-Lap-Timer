
--[[
Ultimate Lap Timer	written by Gregg Novosad (Diviner Gregg) 11/14/2014.

thanks to  Nigel Sheffield, on4mj (Mike) and Kilrah from RCG for answers to posts
=============================================================================
USAGE

Switch B >> - neutral, up applies best Run, down applies ideal lap
Switch C >> - neutral, up resets current time, down resets all times
Slider Knobs change user input fields
Slider S1 >> Maximum number of laps up to 4
Slider S2 >> Check point time plays a sound for each lap

]]

--=== v v v v v ==== User modifiable variables ===== v v v v ==============

--                      you can reassign these switches
--									vv

local applySwitch 	= getFieldInfo("sb").id --<< Apply  best run
local resetSwitch 	= getFieldInfo("sc").id --<< Apply best lap/ideal run


local lapSlider 	= getFieldInfo("s1").id --<< Maximum number of laps
local ChkSlider 	= getFieldInfo("s2").id --<< check point time

local throttleChannel = 1 --throtlle channel default is 1

--==== ^ ^ ^ ^ =================================== ^ ^ ^ ^ ===============


local lapSwitch 	= getFieldInfo("sh").id --
local resetSwitchFlg = 0
local lapSwitchFlg   = 0
local applySwitchFlg = 0

local chkPnt		= 0
local maxLapCnt		= 0

local curLapCnt 	= 0

local bestLapTime 	= {999999,999999,999999,999999,999999,999999}
local bestRunTime 	= {999999,999999,999999,999999,999999,999999}
local bestRunPct 	= {99,99,99,99,99,99}
local bestLapTimeTot = 0
local oldLapTimeTot = 999999
local difLapTimeTot = 0

local bestIdx = 0
local i = 0

local curLapTime 	= {0,0, 0, 0}
local curRunTime 	= 0
local curRunStartTime = 0
local curLapStartTime = 0

local curThrPct = {0,0,0,0,0}
local curThrCnt = {0,0,0,0,0}
local curThrAvg = {0,0,0,0,0}
local curThrPctRun = 0
local curThrCntRun = 0
local curThrAvgRun = 0

local lapRowStr = 19
local lapRowSpc = 9
local lapY      = 0

local errFlg = 0
local ctrStkFlg = 0
local clrRunFlg = 0

local runInfo = 0
local runMsg  = "TreeRacer"

local timer = model.getTimer(0)

local chkStart = 0
local chkFlg = 0
local chkTime = 0
local chkMsg = " "

local raraNbr = 0
local lstLapSlider = -2000

gblTime = 0

----------------------------------------------------------------
local function run()

lcd.clear()

-------------------------------------------------
----- Error Checking
-------------------------------------------------
errFlg = 0
--1) can't start timing unless sb & sc are centered
if getValue(lapSwitch) > 0   then					--	momentary active
	if getValue(resetSwitch) ~= 0 or getValue(applySwitch) ~= 0 then --sticks are not centered

		errFlg = 1	--show the "center stick message" until both sticks are centered
	end
end

if errFlg == 1  and ctrStkFlg == 0 then					--	momentary active
	playFile("SOUNDS/en/ftr/hctrbc.wav")  --play "center sticks message" only once
	ctrStkFlg = 1
end

if getValue(resetSwitch) == 0 and getValue(applySwitch) == 0 then
	ctrStkFlg = 0
end

--  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -
--2) cant start unless last lap was cleard maxLapcnt = 0

if getValue(lapSwitch) > 0 and curLapCnt > (maxLapCnt + 1) then
	errFlg = 2
else
	clrRunFlg = 0
end

if errFlg == 2  and clrRunFlg == 0 then					--	momentary active
	playFile("SOUNDS/en/ftr/hclrcu.wav")	  --play "clear run" only once
	clrRunFlg = 1
end


-----------------------------------------------------
---- User Inputs from Sliders
-----------------------------------------------------
if getValue(lapSlider) < -500 then maxLapCnt = 1 else	--# laps righthand side
if getValue(lapSlider) < 1    then maxLapCnt = 2 else
if getValue(lapSlider) < 500  then maxLapCnt = 3 else
									maxLapCnt = 4

end end end


if getValue(ChkSlider) < -600 then	chkPnt = 0			-- checkpoint voice alert
else chkPnt = (1024 + getValue(ChkSlider))/40 end

-----------------------------------------------------
---- Reset Switch moved UP or DOWN  (SC)
-----------------------------------------------------
if errFlg == 0 and (getValue(resetSwitch) ~= 0)  then	--reset all
	curLapCnt 	= 0
	curLapTime 	= {0,0, 0, 0}
	curRunTime 	= 0
	curRunStartTime = 0
	curLapStartTime = 0
	curThrPct = {0,0,0,0,0}
	curThrCnt = {0,0,0,0,0}
	curThrAvg = {0,0,0,0,0}
	curThrAvgRun = 0
end

if errFlg == 0 and (getValue(resetSwitch) > 0)  then	--up reset current
	bestLapTime	= {999999,999999,999999,999999,999999,999999}
	bestRunTime	= {999999,999999,999999,999999,999999,999999}
	bestRunPct 	= {0,0,0,0,0,0}
	oldLapTimeTot = 999999
end

-----------------------------------------------------
---- Apply Best Lap "Ideal" (SB Up)
-----------------------------------------------------

if 	getValue(applySwitch) < 0 then --SB up applies best lAP
	bestLapTimeTot = 0
	for idx = 1, maxLapCnt, 1 do
		if curLapTime[idx] > 0 and bestLapTime[idx] > curLapTime[idx] then
			bestLapTime[idx] = curLapTime[idx]
			bestLapTimeTot = bestLapTimeTot + bestLapTime[idx]
		end
	end
	bestLapTimeTot = 0
	for idx = 1, maxLapCnt, 1 do		--calc best theorical run
		bestLapTimeTot = bestLapTimeTot + bestLapTime[idx]
	end
	if bestLapTimeTot < oldLapTimeTot then

		difLapTimeTot = oldLapTimeTot - bestLapTimeTot

		if oldLapTimeTot < 999999 then

			playNumber(difLapTimeTot/10, 17, PREC1)	--17=seconds
			playFile("SOUNDS/en/ftr/bideal.wav")

		end
	end

	if bestLapTimeTot < oldLapTimeTot and oldLapTimeTot < 999999 then

		runInfo = (oldLapTimeTot - bestLapTimeTot)/10
		runMsg  = "new Ideal "
	end

	oldLapTimeTot = bestLapTimeTot
end


----------------------------------------------------
---- Apply Best Run  (SB Down)
-----------------------------------------------------

if 	getValue(applySwitch) > 0 and
	applySwitchFlg == 0 and
	curRunTime > 0 then --SB down applies best RUN

	bestIdx = 0
	if curRunTime < bestRunTime[5] then
		bestIdx = 5
	end
	if curRunTime < bestRunTime[4] then
		bestIdx = 4
		bestRunPct [5] = bestRunPct [4]
		bestRunTime[5] = bestRunTime[4]
	end
	if curRunTime < bestRunTime[3] then
		bestIdx = 3
		bestRunPct [4] = bestRunPct [3]
		bestRunTime[4] = bestRunTime[3]
	end
	if curRunTime < bestRunTime[2] then
		bestIdx = 2
		bestRunPct [3] = bestRunPct [2]
		bestRunTime[3] = bestRunTime[2]
	end
	if curRunTime < bestRunTime[1] then
		bestIdx = 1
		bestRunPct [2] = bestRunPct [1]
		bestRunTime[2] = bestRunTime[1]
	end

	if bestIdx ~=0 then
		bestRunPct [bestIdx] = curThrAvgRun
		bestRunTime[bestIdx] = curRunTime
	end

	curLapCnt 	= 0
	curLapTime 	= {0,0, 0, 0}
	curRunTime 	= 0
	curRunStartTime = 0
	curLapStartTime = 0
	curThrPct = {0,0,0,0,0}
	curThrCnt = {0,0,0,0,0}
	curThrAvg = {0,0,0,0,0}
	curThrAvgRun = 0

	if bestIdx == 1 then
		playFile("SOUNDS/en/ftr/b1st.wav")
		runMsg = "new best"
		model.setGlobalVariable(7, 1, bestRunTime[1]/10 )
		else
	if bestIdx == 2 then
		playFile("SOUNDS/en/ftr/b2nd.wav")
		runMsg = "2nd best"  else
	if bestIdx == 3 then
		playFile("SOUNDS/en/ftr/b3rd.wav")
		runMsg = "3rd best" else
	if bestIdx == 4 then
		playFile("SOUNDS/en/ftr/b4th.wav")
		runMsg = "4th best"	else
	if bestIdx == 5 then
		playFile("SOUNDS/en/ftr/b5th.wav")
		runMsg = "5th best"
	else
	if bestIdx == 0 then
		playFile("SOUNDS/en/ftr/bnokep.wav")
		runMsg = "no keeper"
	end end end end end end

	applySwitchFlg = 1
end
if 	getValue(applySwitch) <= 0 then
	applySwitchFlg = 0
end

--------------------------------------------------
---- User Pressed Momentary Switch  (SH) NEW LAP
-----------------------------------------------------
if getValue(lapSwitch) > 0 and lapSwitchFlg == 0 and errFlg == 0 then
	if 	curLapCnt ==  0 then
	--first Lap, reset RUN
		curRunStartTime  = getTime()
		runMsg  = "start"
		playFile("SOUNDS/en/ftr/hstart.wav")
	end

--	say the lap time if not the last lap
	if curLapCnt > 0 and curLapCnt < maxLapCnt then
		playNumber((getTime() - curLapStartTime)/10, 17, PREC1)	--17=seconds
	end

	curLapStartTime = getTime() 		--new lap, reset LAP
	curLapCnt 		= curLapCnt + 1
	lapSwitchFlg = 1
	curThrPct[curLapCnt] = 0
	curThrCnt[curLapCnt] = 0

	chkStart = getTime()/100			-- checkpoint reset
	chkMsg = "new lap"
	chkFlg = 0

	if curLapCnt == (maxLapCnt + 1) and bestRunTime [1] < 999999 then
		runInfo =  -1 * ((bestRunTime[1] - curRunTime) / 10)

		playNumber(runInfo, 17, PREC1)	--17=seconds

		if runInfo > 0 then			-- runIinfo is the difference from best
			runMsg  = "to go"
			playFile("SOUNDS/en/ftr/btogo.wav")
		else
			runMsg  = "beat best"
			playFile("SOUNDS/en/ftr/bnewb.wav")

			raraNbr = math.random(0,11)
	--		raraNbr = getTime() % 10


			if raraNbr == 1 then
				playFile("SOUNDS/en/ftr/z1tund.wav") else
			if raraNbr == 2 then
				playFile("SOUNDS/en/ftr/z2dady.wav") else
			if raraNbr == 3 then
				playFile("SOUNDS/en/ftr/z3stud.wav") else
			if raraNbr == 4 then
				playFile("SOUNDS/en/ftr/z4gath.wav") else
			if raraNbr == 5 then
				playFile("SOUNDS/en/ftr/z5ped.wav") else
			if raraNbr == 6 then
				playFile("SOUNDS/en/ftr/z6push.wav") else
			if raraNbr == 7 then
				playFile("SOUNDS/en/ftr/z7stol.wav") else
			if raraNbr == 8 then
				playFile("SOUNDS/en/ftr/z8hand.wav") else
			if raraNbr == 9 then
				playFile("SOUNDS/en/ftr/z9swet.wav")
			else
				playFile("SOUNDS/en/ftr/z0chmp.wav")

			end	end end end end end end end end


		end
	end

	if curLapCnt == maxLapCnt then
		runMsg  = "final lap"
		playFile("SOUNDS/en/ftr/hfinlp.wav")
	end
end
if getValue(lapSwitch) < 0 then
	lapSwitchFlg = 0
end

------------------------------------------------------
-- Every cycle calculations (avoid divide by zero)
-----------------------------------------------------

if curLapCnt > 0 and curLapCnt <= maxLapCnt   then			--done every cycle
--	lcd.drawNumber(100,55,getValue(3)           ,SMLSIZE)

	curLapTime[curLapCnt] = getTime() - curLapStartTime

	curThrCnt[curLapCnt] = curThrCnt[curLapCnt] + 1
	curThrPct[curLapCnt] = curThrPct[curLapCnt] + ((1024 + getValue(throttleChannel))/20.48)
--	curThrPct[curLapCnt] = curThrPct[curLapCnt] + ((1024 + getValue(3))/20.48)

	curThrAvg[curLapCnt] = curThrPct[curLapCnt] / curThrCnt[curLapCnt]
	curThrCntRun = curThrCnt[1] + curThrCnt[2] + curThrCnt[3] +curThrCnt[4]
	curThrPctRun = curThrPct[1] + curThrPct[2] + curThrPct[3] +curThrPct[4]
	curThrAvgRun =  curThrPctRun / curThrCntRun

	--	chkpnt
	chkTime = getTime()/100

	if (chkTime - chkStart) > chkPnt and
		chkFlg ==  0 and
		chkPnt > 0 then

		playFile("SOUNDS/en/ftr/chkpnt.wav")
		chkFlg = 1
	end



end

curRunTime = curLapTime[1] + curLapTime[2] + curLapTime[3] + curLapTime[4]

bestLapTimeTot = 0
for idx = 1, maxLapCnt, 1 do
		bestLapTimeTot = bestLapTimeTot + bestLapTime[idx]
end

--==========================================================
--------------- draw screen --------------------------------
--===========================================================

--debug vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
--lcd.drawNumber( 110,28,raraNbr  ,SMLSIZE)
--lcd.drawText(110,46,chkMsg   ,SMLSIZE)
--^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^


---------- Literals & Backgrounds ----------
lcd.drawFilledRectangle( 0, 0, 66, 25, 0 )		--left side timerbg
lcd.drawFilledRectangle( 0,45, 66, 20, 0 )		--left side help bg

lcd.drawText(   2,28, "# Laps"  ,SMLSIZE)		--label #laps
lcd.drawText(   2,37, "Chkpnt" ,SMLSIZE)		--label segtime

lcd.drawLine( 118,08,118,64,SOLID,    0)  				--vertical middle
lcd.drawLine(  69,24,212,24,SOLID,    0) 				--horizontal
lcd.drawFilledRectangle( 66,0, 4, 64, 0)				--left side vertical
lcd.drawText(70, 1,"    run < BEST > lap   ",SMLSIZE +INVERS)  --column header
lcd.drawFilledRectangle( 159,  0, 53, 64, 0 )				--cur run bg
lcd.drawText(175, 1,"Current",SMLSIZE +INVERS)				--current Header literal

----------- Left side --------------
timer = model.getTimer(0)
lcd.drawTimer(8, 10, timer.value, MIDSIZE +INVERS)
lcd.drawChannel(60,11,"vfas-min",SMLSIZE +INVERS)		--battery voltage
--vfas-min 246


lcd.drawNumber(46,28, maxLapCnt  ,SMLSIZE)		--input #laps
lcd.drawNumber(46,37,chkPnt,SMLSIZE)
if chkPnt > 0 then
lcd.drawNumber(64,37,chkPnt  - (chkTime - chkStart)   ,SMLSIZE) end

--++++++++++++++++++++++++++++++++
lcd.drawNumber(22,46,runInfo,SMLSIZE +PREC1 +INVERS) -- message area
lcd.drawText  (24,46,runMsg ,SMLSIZE +INVERS)

lcd.drawNumber(9,55, errFlg  ,SMLSIZE +INVERS)
if errFlg == 0 then
		lcd.drawText(12,55,"----" ,SMLSIZE +INVERS)
	else
	if errFlg == 1 then
		lcd.drawText(12,55,"center B&C" ,SMLSIZE +INVERS)
	end
	if errFlg == 2 then
		lcd.drawText(12,55,"reset needed" ,SMLSIZE +INVERS)
	end
	if errFlg == 3 then
		lcd.drawText(12,55,"need a time" ,SMLSIZE +INVERS)
	end
end

----------- Timing MIDSIZ -------------------

lcd.drawNumber(210,10, curRunTime ,MIDSIZE  +PREC2 +INVERS)
lcd.drawNumber(172, 8, curThrAvgRun ,SMLSIZE +INVERS )

if bestRunTime[1] < 999999 then
	lcd.drawNumber  (118,10,bestRunTime[1],MIDSIZE +PREC2)	--1 best Run top
	lcd.drawNumber  (81, 10,bestRunPct[1] ,SMLSIZE)
end

if bestLapTime[1] < 999999 then
lcd.drawNumber(159,10,bestLapTimeTot ,MIDSIZE +PREC2  ) --2 best Lap top
end

for idx = 1, 4, 1 do
	lapY = lapRowStr + (idx * lapRowSpc)
	if idx <= maxLapCnt then
	lcd.drawNumber(181,lapY,idx            ,SMLSIZE +INVERS) end	--current	lap#
	if curThrAvg[idx] > 0 then
	lcd.drawNumber(172,lapY,curThrAvg[idx] ,SMLSIZE +INVERS) end	--current	pct
	if curLapTime[idx] > 0 then
	lcd.drawNumber(210,lapY,curLapTime[idx],SMLSIZE +PREC2 +INVERS) end--current time
	if bestLapTime[idx] < 999999 then
	lcd.drawNumber(155,lapY,bestLapTime[idx],SMLSIZE +PREC2) end--current time
end

for idx = 2, 5, 1 do
	lapY = lapRowStr + (idx * lapRowSpc)
	if bestRunTime[idx] < 999999 then
		lcd.drawNumber(118,lapY-lapRowSpc,bestRunTime[idx],SMLSIZE +PREC2) --current time
		lcd.drawNumber( 81,lapY-lapRowSpc,bestRunPct [idx],SMLSIZE)
	end
end



end --end run function
return {run=run }



