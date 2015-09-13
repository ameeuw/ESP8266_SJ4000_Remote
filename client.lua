function startConfig()
     print('Config -> start webserver')
     print(node.heap())
     file.remove("init.lua")
     file.open("init.lua", "a+")
     file.writeline('dofile("config.lc")')
     file.close()
     tmr.delay(100000)
     node.restart()
end

function blink(pin, times, delay)	
	local lighton=0
	local count=0
	tmr.alarm(0,delay,1,
		function()
			if lighton==0 then 
				lighton=1 
				pwm.setduty(pin, 1023)
			else 
				lighton=0
				pwm.setduty(pin, 0)
			end
			if count==(times*2-1) then 
				tmr.stop(0) 
			else		
				count=count+1
			end
		end)
end

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
			pwm.setup(pin_led,300,0)
			pwm.start(pin_led)
			
		else
		-- short press received			
			shortPress()
		end
	end)
	tmr.delay(1000)
	gpio.mode(pin_btn,gpio.INT,gpio.PULLUP)
	gpio.trig(pin_btn,"down",checkLongPress)
end

function shortPress()
	if mode==0 then				-- If in picture mode
		sendCmd(1001,0)			-- Take a picture
	else
		if recording==0 then	-- If currently not recording
			sendCmd(2001,1)		-- Start recording
		else					-- If recording
			sendCmd(2001,0)		-- Stop recording
		end
	end
end

function longPress()
	if mode==0 then
		sendCmd(3001,1)
	else
		sendCmd(3001,0)
	end
end

function sendCmd(cmd, par)
	if cmd~=nil and par~=nil then
		get = "/?custom=1&cmd=" .. cmd .. "&par=" .. par
	end
	
	print(get)

	conn=net.createConnection(net.TCP, 0)
    
	conn:on("receive", function(conn, payload)
		if parseXML(payload, cmd)==0 then
			
			if cmd==1001 then
				blink(pin_led,3,100)
			end
			
			if cmd==2001 then
				if par==1 then
					recording = 1
					blink(pin_led,-1,800)
				else
					recording = 0
					tmr.stop(0)
				end
			end
			
			if cmd==3001 then
				if par==1 then
					mode = 1
					blink(pin_led,3,200)
				else
					mode = 0
					blink(pin_led,2,200)
				end
			end
		end
	end )
	
    conn:connect(80,host)
    conn:send("GET "..get.." HTTP/1.1\r\nHost: "..host.."\r\n"
        .."Connection: keep-alive\r\nAccept: */*\r\n\r\n")
end

function parseXML(response, cmd)
	-- print(response)
	
	if response~=nil then
		Cmd = response:match("<Cmd>([^,]+)</Cmd>")
		Status = response:match("<Status>([^,]+)</Status>")
	end
	
	if Cmd~=nil and Status~=nil then
		if tonumber(cmd)==tonumber(Cmd) and tonumber(Status)==tonumber(0) then
			return 0
		else
			return 1
		end
	end
end

if file.open('settings.lua', 'r') then 
    dofile('settings.lua')
	 
	wifi.setmode(wifi.STATION)
	wifi.sta.config(network, password)
	wifi.sta.autoconnect(1)
	tmr.delay(100000)
	 
    pin_led = 3
	pin_btn = 4
	mode = 0
	recording = 0
	
    gpio.mode(pin_btn,gpio.INT,gpio.PULLUP)
    gpio.trig(pin_btn,"low",checkLongPress)
    pwm.setup(pin_led,300,0)
    pwm.start(pin_led)
	
else
    startConfig()
end
