local plugin = {}
do
	local SettingsModule = {
		Source = [[return {
			port = 27843,
			startAutomatically = true,
			exclude = {}
		}]],
		Changed = {}
	}
	function SettingsModule.Changed:Connect(func) end

	local mt = getrawmetatable(game);
	local __namecall = mt.__namecall;
	setreadonly(mt, false);
	mt.__namecall = newcclosure(function(...)
		if checkcaller() then
			local m = getnamecallmethod()
			if m == "RequestAsync" then
				return syn.request(({...})[2]);
			elseif m == "GetAsync" then
				return game:HttpGet(({...})[2]);
			elseif ({...})[1].Name == "AnalyticsService" and m == "FindFirstChild" then
				return SettingsModule;
			end
		end
		return __namecall(...);
	end)
	setreadonly(mt, true);
	
	local toolbar = {}
	function toolbar:CreateButton(name, desc, icon)
		local button = {
			Evt = Instance.new("BindableEvent"),
			Click = {},
			Changed = {},
			Name = name,
		}
		function button:SetActive(t)
			print(button.Name, t)
		end
		function button.Click:Connect(func)
			return button.Evt.Event:Connect(func)
		end
		function button.Changed:Connect(func) end
		print("New btn", button)
		return button;
	end
	function plugin:CreateToolbar(tb_name)
		return toolbar;
	end
	function plugin:OpenScript(src) end
end
