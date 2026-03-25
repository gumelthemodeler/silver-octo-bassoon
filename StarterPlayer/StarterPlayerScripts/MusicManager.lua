-- @ScriptType: LocalScript
local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")

local TRACK_IDS = {
	128410711216086,
	138738069072406,
	136984033293818,
	136875724397582,
	136931928031061,
	136767646038064,
	136341071155543,
	135832906928044,
	133379076510860,
	132347366936691,
	131809963961262
}

local bgmPlayer = Instance.new("Sound")
bgmPlayer.Name = "AOTBackgroundSound"
bgmPlayer.Volume = 0.4
bgmPlayer.Parent = SoundService

local lastTrackIndex = 0

task.spawn(function()
	task.wait(2)

	while true do
		local nextTrackIndex = math.random(1, #TRACK_IDS)
		if #TRACK_IDS > 1 then
			while nextTrackIndex == lastTrackIndex do
				nextTrackIndex = math.random(1, #TRACK_IDS)
			end
		end
		lastTrackIndex = nextTrackIndex

		local trackId = TRACK_IDS[nextTrackIndex]
		bgmPlayer.SoundId = "rbxassetid://" .. tostring(trackId)

		pcall(function()
			ContentProvider:PreloadAsync({bgmPlayer})
		end)

		bgmPlayer:Play()

		if bgmPlayer.TimeLength > 0 then
			bgmPlayer.Ended:Wait()
		else
			task.wait(5)
		end

		task.wait(math.random(1, 3))
	end
end)