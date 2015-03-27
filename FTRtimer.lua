
--[[
=============================================================================
Ultimate Lap Timer	written by Gregg Novosad (Diviner Gregg) 11/14/2014.
thanks to  Nigel Sheffield, on4mj (Mike) and Kilrah from RCG for answers to posts
=============================================================================
USAGE:
Switch SB >> - neutral, up applies best Run, down applies ideal lap
Switch SH >> - start timing | new lap. if held for 3 sec: reset timer
Slider S1 >> Maximum number of laps up to 4
Slider S2 >> Check point time plays a sound for each lap
=============================================================================
]]

--=== v v v v v ==== User modifiable variables ===== v v v v ==============
--                   you can reassign these switches
local applySwitch 	= getFieldInfo("sb").id --<< Apply  best run
local lapSlider 	= getFieldInfo("s1").id --<< Maximum number of laps
local ChkSlider 	= getFieldInfo("s2").id --<< check point time
local lapSwitch 	= getFieldInfo("sh").id
local throttleChannel	= 1			-- throttle channel default is 1
--==== ^ ^ ^ ^ =================================== ^ ^ ^ ^ ===============

local resetAppliedTime	= 0
local lapSwitch_prev	= 0
local applySwitch_prev	= 0
local lapValuesSaved	= 0

local chkPnt		= 0
local maxLapCnt		= 0

local curLapCnt 	= 0

local bestLapTime 	= {999999,999999,999999,999999,999999,999999}
local bestRunTime 	= {999999,999999,999999,999999,999999,999999}
local bestRunPct 	= {99,99,99,99,99,99}
local bestLapTimeTot	= 0
local oldLapTimeTot	= 999999
local difLapTimeTot	= 0

local curLapTime	= {0,0,0,0}
local curRunTime	= 0
local curRunStartTime	= 0
local curLapStartTime	= 0

local curThrPct = {0,0,0,0,0}
local curThrCnt = {0,0,0,0,0}
local curThrAvg = {0,0,0,0,0}
local curThrPctRun = 0
local curThrCntRun = 0
local curThrAvgRun = 0

local errFlg = 0
local clrRunFlg = 0

local runInfo = 0

local chkStart = 0
local chkFlg = 0
local chkTime = 0
local chkMsg = " "

local lstLapSlider = -2000

--vv-- Program wide variables --vv--
local runMsg  = "- - - -"
local STATE_IDLE = 0
local STATE_RUNNING = 1
--^^-- Program wide variables --^^--

--vv-- Helper functions --vv--
function round(num, idp)
  local mult = 10^(idp or 0)
  return math.floor(num * mult + 0.5) / mult
end

local function drawNotification(text)
	lcd.drawText(12,55,text ,SMLSIZE +INVERS)
end

local function drawScreen(momentarySecs)
	--==========================================================
	--------------- draw screen --------------------------------
	--===========================================================
	
	---------- Literals & Backgrounds ----------
	lcd.drawFilledRectangle( 0, 0, 66, 25, 0 )		--left side timerbg
	lcd.drawFilledRectangle( 0,45, 66, 20, 0 )		--left side help bg
	
	lcd.drawText(   2,28, "# Laps"  ,SMLSIZE)		--label #laps
	lcd.drawText(   2,37, "Chkpnt" ,SMLSIZE)		--label segtime
	
	lcd.drawLine( 118,08,118,64,SOLID,    0)  		--vertical middle
	lcd.drawLine(  69,24,212,24,SOLID,    0) 		--horizontal
	lcd.drawFilledRectangle( 66,0, 4, 64, 0)		--left side vertical
	lcd.drawText(70, 1,"    run < BEST > lap   ",SMLSIZE +INVERS)  --column header
	lcd.drawFilledRectangle( 159,  0, 53, 64, 0 )		--cur run bg
	lcd.drawText(175, 1,"Current",SMLSIZE +INVERS)		--current Header literal
	
	----------- Left side --------------
	timer = model.getTimer(0)
	lcd.drawTimer(8, 10, timer.value, MIDSIZE +INVERS)
	lcd.drawChannel(60,11,"vfas-min",SMLSIZE +INVERS)	--battery voltage
	
	lcd.drawNumber(46,28, maxLapCnt  ,SMLSIZE)		--input #laps
	lcd.drawNumber(46,37,chkPnt,SMLSIZE)
	if chkPnt > 0 then
		lcd.drawNumber(64,37,chkPnt  - (chkTime - chkStart)   ,SMLSIZE) 
	end
	
	--++++++++++++++++++++++++++++++++
	lcd.drawNumber(22,46,runInfo,SMLSIZE +PREC1 +INVERS) -- message area
	lcd.drawText  (24,46,runMsg ,SMLSIZE +INVERS)
	
	if errFlg == 0 then drawNotification("          ") end
	if errFlg == 1 then drawNotification("center B&C") end
	if errFlg == 2 then drawNotification("reset needed") end
	if errFlg == 3 then drawNotification("need a time") end
	
	----------- Timing MIDSIZ -------------------
	
	lcd.drawNumber(210,10, curRunTime ,MIDSIZE  +PREC2 +INVERS)
	lcd.drawNumber(172, 8, curThrAvgRun ,SMLSIZE +INVERS )

	-- local variables for spacing the text
	local lapY = 0
	local lapRowStr = 19
	local lapRowSpc = 9

	-- Best runs: first the best run with big letters and then runs 2 to 5
	if bestRunTime[1] < 999999 then
		lcd.drawNumber  (118,10,bestRunTime[1],MIDSIZE +PREC2)
		lcd.drawNumber  (81, 10,bestRunPct[1] ,SMLSIZE)
	end
	for idx = 2, 5, 1 do
		lapY = lapRowStr + (idx * lapRowSpc)
		if bestRunTime[idx] < 999999 then
			lcd.drawNumber(118,lapY-lapRowSpc,bestRunTime[idx],SMLSIZE +PREC2) 
			lcd.drawNumber( 81,lapY-lapRowSpc,bestRunPct [idx],SMLSIZE)
		end
	end

	-- Best laps: first the best total time with big letters and then runs 1 to 4
	if bestLapTime[1] < 999999 then
		bestLapTimeTot = 0
		for idx = 1, maxLapCnt, 1 do
			bestLapTimeTot = bestLapTimeTot + bestLapTime[idx]
		end
		lcd.drawNumber(159,10,bestLapTimeTot ,MIDSIZE +PREC2  ) 
	end
	for idx = 1, 4, 1 do
		lapY = lapRowStr + (idx * lapRowSpc)
		if bestLapTime[idx] < 999999 then lcd.drawNumber(155,lapY,bestLapTime[idx],SMLSIZE +PREC2) end  -- time
		if idx <= maxLapCnt	then lcd.drawNumber(181,lapY,idx            ,SMLSIZE +INVERS) end	-- lap#
		if curThrAvg[idx] > 0	then lcd.drawNumber(172,lapY,curThrAvg[idx] ,SMLSIZE +INVERS) end	-- pct
		if curLapTime[idx] > 0	then lcd.drawNumber(210,lapY,curLapTime[idx],SMLSIZE +PREC2 +INVERS) end-- time
	end
	-- Draw dots that show the time momentary switch has been kept on
	if momentarySecs > 1 then
		drawNotification("      ")
		for idx = 1, (momentarySecs -1) * 3, 1 do
			lcd.drawText(12 + (idx * 4), 55, "." ,SMLSIZE +INVERS)
		end
	end
end

local function sayRandomComment()
	randNbr = 0
	randNbr = math.random(0,11)		-- say additional random comment
	if randNbr == 1 then
		playFile("SOUNDS/en/ftr/z1tund.wav") 
	elseif randNbr == 2 then
		playFile("SOUNDS/en/ftr/z2dady.wav") 
	elseif randNbr == 3 then
		playFile("SOUNDS/en/ftr/z3stud.wav") 
	elseif randNbr == 4 then
		playFile("SOUNDS/en/ftr/z4gath.wav") 
	elseif randNbr == 5 then
		playFile("SOUNDS/en/ftr/z5ped.wav") 
	elseif randNbr == 6 then
		playFile("SOUNDS/en/ftr/z6push.wav") 
	elseif randNbr == 7 then
		playFile("SOUNDS/en/ftr/z7stol.wav") 
	elseif randNbr == 8 then
		playFile("SOUNDS/en/ftr/z8hand.wav") 
	elseif randNbr == 9 then
		playFile("SOUNDS/en/ftr/z9swet.wav")
	else
		playFile("SOUNDS/en/ftr/z0chmp.wav")
	end
end
--^^-- Helper functions --^^--

local function resetTimers()
	curLapCnt 	= 0
	curLapTime 	= {0,0,0,0}
	curRunTime 	= 0
	curRunStartTime = 0
	curLapStartTime = 0
	curThrPct	= {0,0,0,0,0}
	curThrCnt	= {0,0,0,0,0}
	curThrAvg	= {0,0,0,0,0}
	curThrAvgRun	= 0
end

local function checkErrors()
	-------------------------------------------------
	----- Error Checking
	-------------------------------------------------
	errFlg = 0
	ctrStkFlg = 0
	--1) can't start timing unless sb & sc are centered
	if getValue(lapSwitch) > 0   then					--	momentary active
		if getValue(applySwitch) ~= 0 then --sticks are not centered
			errFlg = 1	--show the "center stick message" until both sticks are centered
		end
	end
	
	if errFlg == 1  and ctrStkFlg == 0 then					--	momentary active
		playFile("SOUNDS/en/ftr/hctrbc.wav")  --play "center sticks message" only once
		ctrStkFlg = 1
	end
	if getValue(applySwitch) == 0 then
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
	
end

local function applyBestLap()
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

local function applyBestRun()
	if lapValuesSaved == 1 then
		resetTimers()
		lapValuesSaved	= 0
	else
		local bestIdx = 0
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
	
		if bestIdx == 1 then
			playFile("SOUNDS/en/ftr/b1st.wav")
			runMsg = "new best"
			model.setGlobalVariable(7, 1, bestRunTime[1]/10 )
		elseif bestIdx == 2 then
			playFile("SOUNDS/en/ftr/b2nd.wav")
			runMsg = "2nd best"
		elseif bestIdx == 3 then
			playFile("SOUNDS/en/ftr/b3rd.wav")
			runMsg = "3rd best" 
		elseif bestIdx == 4 then
			playFile("SOUNDS/en/ftr/b4th.wav")
			runMsg = "4th best"	
		elseif bestIdx == 5 then
			playFile("SOUNDS/en/ftr/b5th.wav")
			runMsg = "5th best"
		elseif bestIdx == 0 then
			playFile("SOUNDS/en/ftr/bnokep.wav")
			runMsg = "no keeper"
		end
		lapValuesSaved = 1
	end
end

local function applySingleLap()
	curLapStartTime = getTime() 				--new lap, reset LAP

	if curLapCnt ==  0 then
		curRunStartTime  = getTime() --first Lap, reset RUN
		runMsg  = "start"
		playFile("SOUNDS/en/ftr/hstart.wav")
	end

	curLapCnt = curLapCnt + 1
	curThrPct[curLapCnt] = 0
	curThrCnt[curLapCnt] = 0

	chkMsg = "new lap"
	chkFlg = 0

	if curLapCnt > 1 then
		if curLapCnt == (maxLapCnt + 1) then 			-- goal
			runMsg  = " /# GOAL"
			playFile("SOUNDS/en/_kling.wav")
		end
		playNumber((getTime() - curLapStartTime)/10, 17, PREC1)	-- say the lap time (17=seconds)
		if curLapCnt == maxLapCnt then				-- final lap
			runMsg  = "final lap"
			playFile("SOUNDS/en/ftr/hfinlp.wav")
		end
		if curLapCnt == (maxLapCnt + 1) then 			-- goal
			playNumber((curRunTime / 10), 17, PREC1)		-- say this run time
			if  bestRunTime [1] < 999999 then			-- if there is a best lap
				runInfo =  -1 * ((bestRunTime[1] - curRunTime) / 10)	-- runIinfo is the difference from best
				playNumber(runInfo, 17, PREC1)			-- say difference to best run 
				if runInfo > 0 then				
					runMsg  = "to go"
					playFile("SOUNDS/en/ftr/btogo.wav")
				else
					runMsg  = "beat best"
					playFile("SOUNDS/en/ftr/bnewb.wav")
					sayRandomComment()
				end
			end
		end
	end
end

--vv-- Main function that gets repeated --vv--
local function run()
	lcd.clear()
	local state = STATE_IDLE

	if curLapCnt > 0 and curLapCnt <= maxLapCnt and errFlg == 0 then -- are currently flying laps
		state = STATE_RUNNING
	else
		state = STATE_IDLE
	end
	
	if state == STATE_IDLE then
		-----------------------------------------------------
		---- User Inputs from Sliders
		-----------------------------------------------------
		--# laps righthand side
		if getValue(lapSlider) < -500 then maxLapCnt = 1 
		elseif getValue(lapSlider) < 1 then maxLapCnt = 2 
		elseif getValue(lapSlider) < 500  then maxLapCnt = 3 
		else
			maxLapCnt = 4
		end

		--# chkpoint timer
		chkPnt = (1024 + getValue(ChkSlider))/40 -- checkpoint for voice alert
		if chkPnt < 5 then chkPnt = 5 end

		-----------------------------------------------------
		---- Apply Best Lap "Ideal" (SB Up)
		-----------------------------------------------------
		if getValue(applySwitch) < 0 and applySwitch_prev == 0 then --SB up applies best lAP
			applyBestLap()
			applySwitch_prev = -1
		end
		
		----------------------------------------------------
		---- Apply Best Run  (SB Down)
		-----------------------------------------------------
		if getValue(applySwitch) > 0 and applySwitch_prev == 0 and curRunTime > 0 then --SB down applies best RUN
			applyBestRun()
			applySwitch_prev = 1
		end
		if getValue(applySwitch) <= 0 then
			applySwitch_prev = 0
		end

	end

	--------------------------------------------------
	---- User Uses Momentary Switch  (SH) NEW LAP
	--------------------------------------------------
	local momentarySwitchSecs = 0
	if getValue(lapSwitch) > 0 then  -- momentary switch pulled
		if lapSwitch_prev == 0 then
			applySingleLap()
			if state == STATE_RUNNING then chkStart = getTime()/100 end -- checkpoint reset
		end

		-- take note when the momentary switch was turned on
		if resetAppliedTime == 0 then 
			resetAppliedTime = getTime() / 100
		end
		-- if user has kept the momentary switch on for 3 sec then reset current run
		momentarySwitchSecs = (getTime()/100) - resetAppliedTime
		if momentarySwitchSecs > 3 then 
			resetTimers()
			resetAppliedTime = 0
			momentarySwitchSecs = 3
		end
		lapSwitch_prev = 1
	else				-- momentary switch not pulled
		resetAppliedTime = 0
		lapSwitch_prev = 0
	end

	if state == STATE_RUNNING then
		------------------------------------------------------
		-- Every cycle calculations
		-----------------------------------------------------
		if curLapCnt > 0 and curLapCnt <= maxLapCnt then
			curLapTime[curLapCnt] = getTime() - curLapStartTime
			curThrCnt[curLapCnt] = curThrCnt[curLapCnt] + 1
			curThrPct[curLapCnt] = curThrPct[curLapCnt] + ((1024 + getValue(throttleChannel))/20.48)
			curThrAvg[curLapCnt] = curThrPct[curLapCnt] / curThrCnt[curLapCnt]
			curThrCntRun = curThrCnt[1] + curThrCnt[2] + curThrCnt[3] +curThrCnt[4]
			curThrPctRun = curThrPct[1] + curThrPct[2] + curThrPct[3] +curThrPct[4]
			curThrAvgRun =  curThrPctRun / curThrCntRun
	
			-- check if checkpoint timer reached
			chkTime = getTime()/100 		
			if (chkTime - chkStart) > chkPnt and chkFlg ==  0 and chkPnt > 0 then
				playFile("SOUNDS/en/ftr/chkpnt.wav")
				chkFlg = 1
			end
		end
		
		curRunTime = curLapTime[1] + curLapTime[2] + curLapTime[3] + curLapTime[4]
	end
	
	drawScreen(momentarySwitchSecs)
end --end run function
--^^-- Main function that gets repeated --^^--

return { run=run }



