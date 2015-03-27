
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

--vv-- Program wide variables --vv--
local runMsg  = "- - - -"
local STATE_IDLE = 0
local STATE_RUNNING = 1

local resetAppliedTime	= 0
local lapSwitch_prev	= 0
local applySwitch_prev	= 0
local lapValuesSaved	= 0

local bestLapsSet = 0

--^^-- Program wide variables --^^--

local chkPnt		= 0
local lapsTotal		= 0
local currentLapNumber 	= 0

local bestLapTimes 	= {999999,999999,999999,999999,999999,999999}
local bestRunTimes 	= {999999,999999,999999,999999,999999,999999}
local bestRunPct 	= {99,99,99,99,99,99}
local ultimateRunTime	= 0 -- runtime of the best laps

local curRunLapTimes	= {0,0,0,0}
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
	
	lcd.drawNumber(46,28, lapsTotal  ,SMLSIZE)		--input #laps
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
	if bestRunTimes[1] < 999999 then
		lcd.drawNumber  (118,10,bestRunTimes[1],MIDSIZE +PREC2)
		lcd.drawNumber  (81, 10,bestRunPct[1] ,SMLSIZE)
	end
	for idx = 2, 5, 1 do
		lapY = lapRowStr + (idx * lapRowSpc)
		if bestRunTimes[idx] < 999999 then
			lcd.drawNumber(118,lapY-lapRowSpc,bestRunTimes[idx],SMLSIZE +PREC2) 
			lcd.drawNumber( 81,lapY-lapRowSpc,bestRunPct [idx],SMLSIZE)
		end
	end

	-- Best laps: first the best total time with big letters and then runs 1 to 4
	if bestLapTimes[1] < 999999 then
		ultimateRunTime = 0
		for idx = 1, lapsTotal, 1 do
			ultimateRunTime = ultimateRunTime + bestLapTimes[idx]
		end
		lcd.drawNumber(159,10,ultimateRunTime ,MIDSIZE +PREC2  ) 
	end
	for idx = 1, 4, 1 do
		lapY = lapRowStr + (idx * lapRowSpc)
		if bestLapTimes[idx] < 999999 then lcd.drawNumber(155,lapY,bestLapTimes[idx],SMLSIZE +PREC2) end  -- time
		if idx <= lapsTotal	then lcd.drawNumber(181,lapY,idx            ,SMLSIZE +INVERS) end	-- lap#
		if curThrAvg[idx] > 0	then lcd.drawNumber(172,lapY,curThrAvg[idx] ,SMLSIZE +INVERS) end	-- pct
		if curRunLapTimes[idx] > 0	then lcd.drawNumber(210,lapY,curRunLapTimes[idx],SMLSIZE +PREC2 +INVERS) end-- time
	end
	-- Draw dots that show the time momentary switch has been kept on
	if momentarySecs > 0.5 then
		drawNotification("      ")
		for idx = 1, (momentarySecs - 0.5) * 4, 1 do
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
	playFile("SOUNDS/en/_squish.wav") -- reset
	currentLapNumber 	= 0
	curRunLapTimes 	= {0,0,0,0}
	curRunTime 	= 0
	curRunStartTime = 0
	curLapStartTime = 0
	curThrPct	= {0,0,0,0,0}
	curThrCnt	= {0,0,0,0,0}
	curThrAvg	= {0,0,0,0,0}
	curThrAvgRun	= 0
	bestLapsSet	= 0
	lapValuesSaved	= 0
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
	--2) cant start unless last lap was cleard lapsTotal = 0

	if getValue(lapSwitch) > 0 and currentLapNumber > (lapsTotal + 1) then
		errFlg = 2
	else
		clrRunFlg = 0
	end
	
	if errFlg == 2  and clrRunFlg == 0 then					--	momentary active
		playFile("SOUNDS/en/ftr/hclrcu.wav")	  --play "clear run" only once
		clrRunFlg = 1
	end
	
end

local function applyBestLaps()
	if bestLapsSet == 0 then
		-- loop all the laps
		for i = 1, lapsTotal, 1 do
			-- loop all the best laps
			for j = 1, #bestLapTimes, 1 do  -- # means the length of the array
				-- if this lap is faster that this fastest lap 
				if bestLapsSet < i and curRunLapTimes[i] > 0 and curRunLapTimes[i] < bestLapTimes[j] then
					-- move all the numbers one slot forward
					for k = #bestLapTimes, j+1, -1 do
						bestLapTimes[k] = bestLapTimes[k-1]
					end
					-- inset lap into its place
					bestLapTimes[j] = curRunLapTimes[i]
					if j == 1 then
						playFile("SOUNDS/en/ftr/newblap.wav") -- new best lap
						playNumber(bestLapTimes[1]/10, 17, PREC1)	
					end
					-- no need to continue with the faster best laps
					bestLapsSet = bestLapsSet + 1
				end
			end
		end
	end
	
	local ultimateRunTime = 0
	for idx = 1, lapsTotal, 1 do		--calc best theorical run
		ultimateRunTime = ultimateRunTime + bestLapTimes[idx]
	end
	ultimateRunTime = runTimeTotal
end

local function applyBestRun()
	if lapValuesSaved == 1 then
		-- resetTimers()
	else
		local bestIdx = 0
		if curRunTime < bestRunTimes[5] then
			bestIdx = 5
		end
		if curRunTime < bestRunTimes[4] then
			bestIdx = 4
			bestRunPct [5] = bestRunPct [4]
			bestRunTimes[5] = bestRunTimes[4]
		end
		if curRunTime < bestRunTimes[3] then
			bestIdx = 3
			bestRunPct [4] = bestRunPct [3]
			bestRunTimes[4] = bestRunTimes[3]
		end
		if curRunTime < bestRunTimes[2] then
			bestIdx = 2
			bestRunPct [3] = bestRunPct [2]
			bestRunTimes[3] = bestRunTimes[2]
		end
		if curRunTime < bestRunTimes[1] then
			bestIdx = 1
			bestRunPct [2] = bestRunPct [1]
			bestRunTimes[2] = bestRunTimes[1]
		end
	
		if bestIdx ~=0 then
			bestRunPct [bestIdx] = curThrAvgRun
			bestRunTimes[bestIdx] = curRunTime
		end
	
		if bestIdx == 1 then
			playFile("SOUNDS/en/ftr/b1st.wav")
			runMsg = "new best"
			model.setGlobalVariable(7, 1, bestRunTimes[1]/10 )
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

local function applySingleLap(state)
	if currentLapNumber ==  0 then
		curRunStartTime  = getTime()	-- first Lap, reset RUN
		curLapStartTime = getTime()	-- reset LAP
		runMsg  = "start"
		playFile("SOUNDS/en/ftr/hstart.wav")
		state = STATE_RUNNING
	end

	currentLapNumber = currentLapNumber + 1
	if currentLapNumber > lapsTotal + 1 then currentLapNumber = lapsTotal + 1 end	-- keeps the number there

	if state == STATE_RUNNING then
		curThrPct[currentLapNumber] = 0
		curThrCnt[currentLapNumber] = 0
		currLapTime = 0
		chkMsg = "new lap"
		chkFlg = 0
	
		if currentLapNumber > 1 then
			if currentLapNumber == (lapsTotal + 1) then 			-- goal
				runMsg  = " /# GOAL"
				playFile("SOUNDS/en/_kling.wav")
			end
			currLapTime = getTime() - curLapStartTime
			playNumber(currLapTime/10, 17, PREC1)	-- say the lap time (17=seconds)
			if currentLapNumber == lapsTotal then				-- final lap
				runMsg  = "final lap"
				playFile("SOUNDS/en/ftr/hfinlp.wav")
			end
			if currentLapNumber == (lapsTotal + 1) then 			-- goal
				playNumber((curRunTime / 10), 17, PREC1)		-- say this run time
				if  bestRunTimes [1] < 999999 then			-- if there is a best lap
					runInfo =  -1 * ((bestRunTimes[1] - curRunTime) / 10)	-- runIinfo is the difference from best
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
	curLapStartTime = getTime() 				--new lap, reset LAP
	return state
end

--vv-- Main function that gets repeated --vv--
local function run()
	lcd.clear()
	local state = STATE_IDLE

	if currentLapNumber > 0 and currentLapNumber <= lapsTotal and errFlg == 0 then -- are currently flying laps
		state = STATE_RUNNING
	else
		state = STATE_IDLE
	end
	
	if state == STATE_IDLE then
		-----------------------------------------------------
		---- User Inputs from Sliders
		-----------------------------------------------------
		--# laps righthand side
		if getValue(lapSlider) < -500 then lapsTotal = 1 
		elseif getValue(lapSlider) < 1 then lapsTotal = 2 
		elseif getValue(lapSlider) < 500  then lapsTotal = 3 
		else
			lapsTotal = 4
		end

		--# chkpoint timer
		chkPnt = (1024 + getValue(ChkSlider))/40 -- checkpoint for voice alert
		if chkPnt < 5 then chkPnt = 5 end

		-----------------------------------------------------
		---- Apply Best Lap "Ideal" (SB Up)
		-----------------------------------------------------
		if getValue(applySwitch) < 0 and applySwitch_prev == 0 then --SB up applies best lAP
			applyBestLaps()
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
			state = applySingleLap(state)
			if state == STATE_RUNNING then chkStart = getTime()/100 end -- checkpoint reset
		end

		-- take note when the momentary switch was turned on
		if resetAppliedTime == 0 then 
			resetAppliedTime = getTime() / 100
		end
		-- if user has kept the momentary switch on for 3 sec then reset current run
		momentarySwitchSecs = (getTime()/100) - resetAppliedTime
		if momentarySwitchSecs > 2 then 
			resetTimers()
			resetAppliedTime = 0
			momentarySwitchSecs = 2
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
		if currentLapNumber > 0 and currentLapNumber <= lapsTotal then
			curRunLapTimes[currentLapNumber] = getTime() - curLapStartTime
			curThrCnt[currentLapNumber] = curThrCnt[currentLapNumber] + 1
			curThrPct[currentLapNumber] = curThrPct[currentLapNumber] + ((1024 + getValue(throttleChannel))/20.48)
			curThrAvg[currentLapNumber] = curThrPct[currentLapNumber] / curThrCnt[currentLapNumber]
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
		
		curRunTime = curRunLapTimes[1] + curRunLapTimes[2] + curRunLapTimes[3] + curRunLapTimes[4]
	end
	
	drawScreen(momentarySwitchSecs)
end --end run function
--^^-- Main function that gets repeated --^^--

return { run=run }



