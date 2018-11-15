-- SEAL.lua (version 0.11, 08/30/2016)
-- IDS Project
-- 
-- Opens SEAL Catalog for ISBN/ISSN/OCLC Number/Title String Search
-- SEAL Discussion

-- Lending Request Creation
-- Copy and paste email and parse data
-- Save and close

-- Open Lending request
-- Begin catalog search (SEAL)
-- Import remaining information
-- Process Lending Request Normally

-- SEAL Addon 
	-- Borrowing Side
	-- Set error to True
	-- Auto Login when Request Click
	-- After log in, import library information from drop down
		-- Notes field?
		-- Make work with Email Routing

	



-- define your SEAL Catalog Search string options
local settings = {};

if string.find (GetSetting("SEALBaseURL"),"http",1,true) ~= nil then
	settings.myBaseURL = GetSetting("SEALBaseURL")
else
	settings.myBaseURL = "http://" .. GetSetting("SEALBaseURL") .. "/search.html?query=";
end

settings.UseOCLCNum = GetSetting("UseOCLCNum");
settings.UserID = GetSetting("UserID");
settings.Password = GetSetting("Password");
settings.TabSwitch = "Detail";
settings.searchpage ="http://senylrc.indexdata.com/advanced.html?query=";

local interfaceMngr = nil;
local SEAL = {};
SEAL.Form = nil;
SEAL.Browser = nil;
SEAL.RibbonPage = nil;
SEAL.EMailForm = nil;
SEAL.EMailRibbonPage = nil;
SEAL.OpenImport = nil;
SEAL.ImportEmail = nil;
SEAL.EMailBrowser = nil;
SEAL.EmailImportField = nil;



require "Atlas.AtlasHelpers";

function Init()


		interfaceMngr = GetInterfaceManager();
 
		-- Create a form
		SEAL.Form = interfaceMngr:CreateForm("SEAL Search", "Script");
		 
		-- Add a browser for SEAL and Alias
		SEAL.Browser = SEAL.Form:CreateBrowser("SEAL Search", "SEAL Browser", "SEAL Citation");
		--SEAL.EMailBrowser = SEAL.EMailForm:CreateBrowser("SEAL Importer", "SEAL Importer Browser", "SEAL Importer");
		-- Hide the text label
		SEAL.Browser.TextVisible = false;
      
		--SuppreSEAL Javascript errors
		SEAL.Browser.WebBrowser.ScriptErrorsSuppressed = true;

		-- Since we didn't create a ribbon explicitly before creating our browser, it will have created one using the name we passed the CreateBrowser method.  We can retrieve that one and add our buttons to it.
		SEAL.RibbonPage = SEAL.Form:GetRibbonPage("SEAL Citation");

 
		-- Create the buttons
		SEAL.ImportButton = SEAL.RibbonPage:CreateButton("Import Call Number", GetClientImage("Search32"), "importCallNumber", "SEAL");
		SEAL.ImportButton.BarButton.Enabled = false;
		local url = "http://seal2.senylrc.org/user";
		SEAL.Browser:Navigate(url);
		SEAL.Browser:RegisterPageHandler("formExists", "user-login", "LogintoSeal", true);	
		--SEAL.Browser:RegisterPageHandler("formExists", "search", "Search", true);
		if GetFieldValue("Transaction", "LoanTitle")~= "" then
			Search();
		else
		SEAL.EMailForm = interfaceMngr:CreateForm("SEAL EMail Import", "Script");
		SEAL.EMailRibbon = SEAL.EMailForm:CreateRibbonPage("Email Import");
		SEAL.OpenImport = SEAL.EMailRibbon:CreateButton("Import Email", GetClientImage("Forward32"), "ImportEmail", "SEAL New Request");
		SEAL.EMailForm:Show();
		SEAL.EmailImportField = SEAL.EMailForm:CreateMemoEdit("EmailImportField", "Email Import:");
			--ImportEmail();
	end
end

function LogintoSeal()
	SEAL.Browser:SetFormValue("user-login", "edit-name", settings.UserID);
	SEAL.Browser:SetFormValue("user-login", "edit-pass", settings.Password);
	SEAL.Browser:SubmitForm("user-login");
	--SEAL.Browser:redirect("http://senylrc.indexdata.com/advanced.html?query=");


end


function Search()
	local myISxN = GetFieldValue("Transaction", "ISSN");

    if myISxN:len()>9 then
		--   build URL for ISBN
		if string.find(myISxN," ",1)~=nil then
			myISxN = string.sub(myISxN,1,string.find(myISxN," ",1,true)-1);
		end
		--SENYLRC Revmoed ISBN so it was not in search string
		--myURL = settings.myBaseURL .. "isbn:" .. myISxN .. "&sort=relevance&perpage=20";
		myURL = settings.myBaseURL .. "" .. myISxN .. "&sort=relevance&perpage=20";
	elseif GetFieldValue("Transaction", "RequestType") == "Article" then
			--   build URL for articles
			local myTitle = GetFieldValue("Transaction", "PhotoJournalTitle");
			local A = GetFieldValue("Transaction", "PhotoJournalTitle");
			--SENYLRC Removed issn so not in search string
			--myURL = settings.myBaseURL .. "issn:" .. myISxN .. "ti:" .. myTitle .. "&sort=relevance&perpage=20";
			myURL = settings.myBaseURL .. "" .. myISxN .. "ti:" .. myTitle .. "&sort=relevance&perpage=20";
	else
			-- build URL for books and other 'returnables'
			local myTitle = string.gsub(GetFieldValue("Transaction", "LoanTitle"),"/","");
			--SENYLRC Removed ti so not in search string
			--myURL = settings.myBaseURL .. "ti:" .. AtlasHelpers.UrlEncode(myTitle) .. "&sort=relevance&perpage=20";
			myURL = settings.myBaseURL .. "" .. AtlasHelpers.UrlEncode(myTitle) .. "&sort=relevance&perpage=20";
	end
	--end
	SEAL.Browser:RegisterPageHandler("custom", "checkButton", "activateButton", true);
	SEAL.Browser:Navigate(myURL);
	SEAL.Form:Show();
	
end

function checkButton()
	if string.find(SEAL.Browser.WebBrowser.DocumentText,"Full Record View")~=nil then
		return true;
	else
		SEAL.ImportButton.BarButton.Enabled = false;
		return false;
	end
end

function activateButton()
	SEAL.ImportButton.BarButton.Enabled = true;
end

function importCallNumber()
	local SimpleSearchDiv = SEAL.Browser:GetElementInFrame(nil, "locationsTable");
	local call_Number = string.match(SimpleSearchDiv.Innerhtml,"%u+%s*%d+%.*%d*%s*%.*%u+%s*%d+%s%u+%s*%d+%s%d*",1)
	SetFieldValue("Transaction", "CallNumber", call_Number);
	if string.find(string.lower(SimpleSearchDiv.Innerhtml), "available") >0 then
		SetFieldValue("Transaction", "ItemInfo1", "Available");
	else
		SetFieldValue("Transaction", "ItemInfo1", "Unavailable");
	end
	ExecuteCommand("SwitchTab", {settings.TabSwitch});
end

--  ImportEmail Section

function ImportEmail()
	--SEAL.EMailForm, SEAL.EMailBrowser, SEAL.OpenImport, SEAL.ImportEmail
	local emailtext = SEAL.EmailImportField.Value;
	local i = 1;
	local tempInfo = nil;
	SetFieldValue("Transaction", "RequestType", "Loan");
	for l in emailtext:gmatch("[^\r\n]+") do
		if i==1 then
			SetFieldValue("Transaction", "ILLNumber", l:match("%((.+)%)"));
		end
		if i == 2 then
			SetFieldValue("Transaction", "LoanTitle", l:match(":%s(.+)"));
		end
		if i == 3 then
			SetFieldValue("Transaction", "LoanAuthor", l:match(":%s(.+)"));
		end
		if i == 4 then
			SetFieldValue("Transaction", "DocumentType", l:match(":%s(.+)"));
		end
		if i == 5 then
			SetFieldValue("Transaction", "LoanDate", l:match(":%s(.+)"));
		end
		if i == 6 then
			SetFieldValue("Transaction", "ISSN", l:match(":%s(.+)"));
		end
		if GetFieldValue("Transaction", "DocumentType")=='book' then
			if i == 2 then
				SetFieldValue("Transaction", "LoanTitle", l:match(":%s(.+)"));
			end
			if i == 3 then
				SetFieldValue("Transaction", "LoanAuthor", l:match(":%s(.+)"));
			end
			if i == 7 then
				SetFieldValue("Transaction", "CallNumber", l:match(":%s(.+)"));
			end
			if i == 8 then
				SetFieldValue("Transaction", "ItemInfo1", l:match(":%s(.+)"));
			end
			if i == 9 then
				SetFieldValue("Transaction", "Location", l:match(":%s(.+)"));
			end
		else
			if i == 2 then
				SetFieldValue("Transaction", "PhotoJournalTitle", l:match(":%s(.+)"));
			end
			if i == 3 then
				SetFieldValue("Transaction", "PhotoJournalAuthor", l:match(":%s(.+)"));
			end
			if i == 7 then
				SetFieldValue("Transaction", "CallNumber", l:match(":%s(.+)"));
			end
			if i == 8 then
				SetFieldValue("Transaction", "ItemInfo1", l:match(":%s(.+)"));
			end
			if i == 9 then
				SetFieldValue("Transaction", "Location", l:match(":%s(.+)"));
			end
			if i == 10 then
				SetFieldValue("Transaction", "PhotoArticleTitle", l:match(":%s(.+)"));
			end
			if i == 11 then
				SetFieldValue("Transaction", "PhotoArticleAuthor", l:match(":%s(.+)"));
			end
			if i == 12 then
				SetFieldValue("Transaction", "PhotoJournalVolume", l:match(":%s(.+)"));
			end
			if i == 13 then
				SetFieldValue("Transaction", "PhotoJournalIssue", l:match(":%s(.+)"));
			end
			if i == 14 then
				SetFieldValue("Transaction", "PhotoJournalInclusivePages", l:match(":%s(.+)"));
			end
			if i == 15 then
				SetFieldValue("Transaction", "PhotoJournalYear", l:match(":%s(.+)"));
			end
			if i == 16 then
				SetFieldValue("Transaction", "PhotoJournalMonth", l:match(":%s(.+)"));
			end
			if i == 17 then
				SetFieldValue("Transaction", "CopyrightComp", l:match(":%s(.+)"));
			end

		end
		i=i+1;
	end
	--ExecuteCommand("SwitchTab", {settings.TabSwitch});
	--		interfaceMngr:ShowMessage(l:match("%((.+)%)"),"Alert");
	Search();
	--SENYLRC added this to default back to detail
	ExecuteCommand("SwitchTab", {settings.TabSwitch});
end

function split(pString, pPattern)
	local Table = {} -- NOTE: use {n = 0} in Lua-5.0
	local fpat = "(.-)" .. pPattern
	local last_end = 1
	local s, e, cap = pString:find(fpat, 1)
	while s do
		if s ~= 1 or cap ~= "" then
			table.insert(Table,cap)
		end
		last_end = e+1
		s, e, cap = pString:find(fpat, last_end)
	end
	if last_end <= #pString then
		cap = pString:sub(last_end)
		table.insert(Table, cap)
	end
	return Table
end
