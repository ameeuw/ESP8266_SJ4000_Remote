-- Start configuration server.
function startConfig()
     print('Config -> start webserver')
     print(node.heap())
     file.remove("startup.lua")
     file.open("startup.lua", "a+")
     file.writeline('dofile("config.lc")')
     file.close()
     tmr.delay(100000)
     node.restart()
end

-- Blink an LED for status feedback.
function blink(pin, times, delay, r, g, b)	
	local lighton=0
	local count=0
	tmr.alarm(0,delay,1,
		function()
			if lighton==0 then 
				lighton=1 
				ws2812.writergb(pin, string.char(r,g,b))
			else 
				lighton=0
				ws2812.writergb(pin, string.char(0,0,0))
			end
			if count==(times*2-1) then 
				tmr.stop(0) 
			else		
				count=count+1
			end
		end)
end

-- Check if button was pressed long
function checkLongPress()
    gpio.mode(pin_btn,gpio.OUTPUT)
	gpio.write(pin_btn,gpio.HIGH)
	tmr.alarm(1,500,0,function()
		if gpio.read(pin_btn)~=gpio.HIGH then
		-- long press received
			longPress()
			
			gpio.mode(pin_led,gpio.INPUT)
			gpio.write(pin_led,gpio.HIGH)
			if gpio.read(pin_led)~=gpio.HIGH then
				print("Reset. Starting configuration!")
				startConfig()
			end			
		else
		-- short press received			
			shortPress()
		end
	end)
	tmr.delay(1000)
	gpio.mode(pin_btn,gpio.INT,gpio.PULLUP)
	gpio.trig(pin_btn,"down",checkLongPress)
end

-- A short press sends the trigger command (shutter for photo- and start/stop for video-mode)
function shortPress()
	if mode==0 then				-- If in photo mode
		sendCmd(1001,0)			-- Take a photo
	else
		if recording==0 then	-- If currently not recording
			sendCmd(2001,1)		-- Start recording
		else					-- If recording
			sendCmd(2001,0)		-- Stop recording
		end
	end
end

-- A long press sends command to change the mode (photo- or video-mode)
function longPress()
	if mode==0 then
		sendCmd(3001,1)
	else
		sendCmd(3001,0)
	end
end

-- SJ4000 exposes a RESTful API to the WiFi-device
-- List of commands:
-- Command  Parameter   Function
-- 1001     -           Take photo
-- 2001     0           Stop recording video
-- 2001     1           Start recording video
-- 3001     0           Switch to photo mode
-- 3001     1           Switch to video mode
function sendCmd(cmd, par)
	if cmd~=nil and par~=nil then
		get = "/?custom=1&cmd=" .. cmd .. "&par=" .. par
	end
	
	print(get)

	conn=net.createConnection(net.TCP, 0)
    
	conn:on("receive", function(conn, payload)
		if parseXML(payload, cmd)==0 then
			
			if cmd==1001 then
				-- Fast blink LED green to mark photo
				blink(pin_led,3,100,0,100,0)
			end
			
			if cmd==2001 then
				if par==1 then
					recording = 1
					-- Slow blink LED red while recording
					blink(pin_led,-1,800,100,0,0)
				else
					recording = 0
					tmr.stop(0)
				end
			end
			
			if cmd==3001 then
				if par==1 then
					-- Switch to video mode successful
					mode = 1
					-- Fast blink LED blue for switching to video mode
					blink(pin_led,3,200,0,0,100)
				else
					-- Switch to photo mode successful
					mode = 0
					-- Fast blink LED purple for switching to photo mode
					blink(pin_led,2,200,60,0,100)
				end
			end
		end
	end )
	
    conn:connect(80,host)
    conn:send("GET "..get.." HTTP/1.1\r\nHost: "..host.."\r\n"
        .."Connection: keep-alive\r\nAccept: */*\r\n\r\n")
end

-- Parse SJ4000 responds with XML-data whether command has succeeded
function parseXML(response, cmd)
	-- print(response)
	
	if response~=nil then
		Cmd = response:match("<Cmd>([^,]+)</Cmd>")
		Status = response:match("<Status>([^,]+)</Status>")
	end
	
	-- If Status for corresponding command is 0, command was successful
	if Cmd~=nil and Status~=nil then
		if tonumber(cmd)==tonumber(Cmd) and tonumber(Status)==tonumber(0) then
			return 0
		else
			return 1
		end
	end
end

-- Load settings, connect to wifi station and register pin-interrupt
if file.open('settings.lua', 'r') then 
    dofile('settings.lua')
	 
	wifi.setmode(wifi.STATION)
	wifi.sta.config(network, password)
	wifi.sta.autoconnect(1)
	tmr.delay(100000)
	 
  pin_led = 4
	pin_btn = 3
	mode = 0
	recording = 0
	
  gpio.mode(pin_btn,gpio.INT,gpio.PULLUP)
  gpio.trig(pin_btn,"low",checkLongPress)
  blink(pin_led,3,200,100,100,100)
    -- gpio.trig(pin_btn,"low",checkLongPress)	
else
    startConfig()
end
