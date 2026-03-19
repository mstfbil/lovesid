-- [yue]: lovesid.yue
local _module_0 = nil -- 1
local bit = require("bit") -- 1

-- define constants
local CLOCK = { -- 5
	PAL = 985248, -- 5
	NTSC = 1022727 -- 6
} -- 4
local SAMPLE_RATE = 44100 -- 7
local SAMPLE_DT = 1 / SAMPLE_RATE -- 8
local ADSR_LOOKUP = { -- 10
	ATTACK = { -- 10
		0.002, -- 10
		0.008, -- 10
		0.016, -- 10
		0.024, -- 10
		0.038, -- 10
		0.056, -- 10
		0.068, -- 10
		0.080, -- 10
		0.100, -- 10
		0.250, -- 10
		0.500, -- 10
		0.800, -- 10
		1.000, -- 10
		3.000, -- 10
		5.000, -- 10
		8.000 -- 10
	}, -- 10
	DECAY = { -- 11
		0.006, -- 11
		0.024, -- 11
		0.048, -- 11
		0.072, -- 11
		0.114, -- 11
		0.168, -- 11
		0.204, -- 11
		0.240, -- 11
		0.300, -- 11
		0.750, -- 11
		1.500, -- 11
		2.400, -- 11
		3.000, -- 11
		9.000, -- 11
		15.00, -- 11
		24.00 -- 11
	}, -- 11
	RELEASE = { -- 12
		0.006, -- 12
		0.024, -- 12
		0.048, -- 12
		0.072, -- 12
		0.114, -- 12
		0.168, -- 12
		0.204, -- 12
		0.240, -- 12
		0.300, -- 12
		0.750, -- 12
		1.500, -- 12
		2.400, -- 12
		3.000, -- 12
		9.000, -- 12
		15.00, -- 12
		24.00 -- 12
	} -- 12
} -- 9
---@enum ENV_STATE
local ENV_STATE = { -- 15
	IDLE = 1, -- 15
	ATTACK = 2, -- 16
	DECAY = 3, -- 17
	SUSTAIN = 4, -- 18
	RELEASE = 5 -- 19
} -- 14

-- define runtime vars
local channels -- 22
do -- 22
	local _accum_0 = { } -- 22
	local _len_0 = 1 -- 22
	for i = 1, 3 do -- 22
		_accum_0[_len_0] = { -- 23
			acc = 0.0, -- 23
			prev_acc = 0.0, -- 23
			env_level = 0, -- 23
			env_state = ENV_STATE.IDLE, -- 23
			noise_reg = 0xfffff, -- 23
			last_bit19 = 0 -- 23
		} -- 23
		_len_0 = _len_0 + 1 -- 23
	end -- 22
	channels = _accum_0 -- 22
end -- 22
local filter = { -- 24
	low = 0, -- 24
	band = 0 -- 24
} -- 24
local buffer_size, buffer_count -- 25

-- module
local _registers = setmetatable({ }, { -- 29
	__index = function(self, k) -- 29
		local _exp_0 = rawget(self, k) -- 30
		if _exp_0 ~= nil then -- 30
			return _exp_0 -- 30
		else -- 30
			return 0 -- 30
		end -- 30
	end -- 29
}) -- 28

local lovesid = setmetatable({ -- 33
	source = love.audio.newQueueableSource(SAMPLE_RATE, 16, 1, buffer_count), -- 44
	is_ntsc = false -- 45
}, { -- 33
	__newindex = function(self, k, v) -- 33
		if type(k) == "number" and 1 <= k and k <= 25 then -- 34
			_registers[k] = bit.band(v, 0xff) -- 35
		else -- 37
			rawset(self, k, v) -- 37
			return -- 38
		end -- 34
	end, -- 33
	__index = function(self, k) -- 39
		if type(k) == "number" then -- 40
			return _registers[k] -- 41
		else -- 43
			return rawget(self, k) -- 43
		end -- 40
	end -- 39
}) -- 32

lovesid.configure = function(self, o) -- 47
	if o == nil then -- 47
		o = { } -- 47
	end -- 47
	do -- 48
		local _exp_0 = o.buffer_size -- 48
		if _exp_0 ~= nil then -- 48
			buffer_size = _exp_0 -- 48
		else -- 48
			buffer_size = 1024 -- 48
		end -- 48
	end -- 48
	do -- 49
		local _exp_0 = o.buffer_count -- 49
		if _exp_0 ~= nil then -- 49
			buffer_count = _exp_0 -- 49
		else -- 49
			buffer_count = 8 -- 49
		end -- 49
	end -- 49
	do -- 50
		local _obj_0 = self.source -- 50
		if _obj_0 ~= nil then -- 50
			_obj_0:stop() -- 50
		end -- 50
	end -- 50
	self.source = love.audio.newQueueableSource(SAMPLE_RATE, 16, 1, buffer_count) -- 51
end -- 47
lovesid:configure() -- 52

local getClock -- 54
getClock = function() -- 54
	return lovesid.is_ntsc and CLOCK.NTSC or CLOCK.PAL -- 55
end -- 54

local getChannelOffset -- 57
getChannelOffset = function(ch) -- 57
	return (ch - 1) * 7 + 1 -- 58
end -- 57

local getFrequency -- 60
getFrequency = function(ch) -- 60
	local offset = getChannelOffset(ch) -- 61
	local lo, hi = _registers[offset], _registers[offset + 1] -- 62
	return bit.bor(bit.lshift(hi, 8), lo) -- 63
end -- 60

local wordToHz -- 65
wordToHz = function(word) -- 65
	return word * getClock() / 16777216 -- 66
end -- 65

local getPulseWidth -- 68
getPulseWidth = function(ch) -- 68
	local offset = getChannelOffset(ch) + 2 -- 69
	local lo, hi = _registers[offset], bit.band(_registers[offset + 1], 0xf) -- 70
	local _exp_0 = bit.bor(bit.lshift(hi, 8), lo) -- 71
	if _exp_0 ~= nil then -- 71
		return _exp_0 -- 71
	else -- 71
		return 0 -- 71
	end -- 71
end -- 68

local getControl -- 73
getControl = function(ch) -- 73
	local offset = getChannelOffset(ch) + 4 -- 74
	local byte = _registers[offset] -- 75
	return { -- 77
		gate = bit.band(byte, 0x01) ~= 0, -- 77
		sync = bit.band(byte, 0x02) ~= 0, -- 78
		ring = bit.band(byte, 0x04) ~= 0, -- 79
		test = bit.band(byte, 0x08) ~= 0, -- 80
		tri = bit.band(byte, 0x10) ~= 0, -- 81
		saw = bit.band(byte, 0x20) ~= 0, -- 82
		pulse = bit.band(byte, 0x40) ~= 0, -- 83
		noise = bit.band(byte, 0x80) ~= 0 -- 84
	} -- 76
end -- 73

local getADSR -- 87
getADSR = function(ch) -- 87
	local offset = getChannelOffset(ch) + 5 -- 88
	local AD, SR = _registers[offset], _registers[offset + 1] -- 89
	return { -- 91
		a = bit.band(bit.rshift(AD, 4), 0xf), -- 91
		d = bit.band(AD, 0xf), -- 92
		s = bit.band(bit.rshift(SR, 4), 0xf), -- 93
		r = bit.band(SR, 0xf) -- 94
	} -- 90
end -- 87

local getVolume -- 97
getVolume = function() -- 97
	local byte = _registers[25] -- 98
	return bit.band(byte, 0xf) -- 99
end -- 97

local getFilterCutoff -- 101
getFilterCutoff = function() -- 101
	local lo, hi = bit.band(_registers[22], 0x7), _registers[23] -- 102
	return bit.bor(lo, bit.lshift(hi, 3)) -- 103
end -- 101

local getFilterResonance -- 105
getFilterResonance = function() -- 105
	local byte = _registers[24] -- 106
	return bit.band(bit.rshift(byte, 4), 0xf) -- 107
end -- 105

local getFilterApply -- 109
getFilterApply = function() -- 109
	local byte = _registers[24] -- 110
	return { -- 112
		bit.band(byte, 0x1) ~= 0, -- 112
		bit.band(byte, 0x2) ~= 0, -- 113
		bit.band(byte, 0x4) ~= 0 -- 114
	} -- 111
end -- 109

local getFilterPass -- 117
getFilterPass = function() -- 117
	local byte = _registers[25] -- 118
	return { -- 120
		low_pass = bit.band(byte, 0x10) ~= 0, -- 120
		band_pass = bit.band(byte, 0x20) ~= 0, -- 121
		high_pass = bit.band(byte, 0x40) ~= 0 -- 122
	} -- 119
end -- 117

local getChannel3Off -- 125
getChannel3Off = function() -- 125
	local byte = _registers[25] -- 126
	return bit.band(byte, 0x80) == 0x80 -- 127
end -- 125

local updateEnvelope -- 129
updateEnvelope = function(ch) -- 129
	local state = channels[ch] -- 130
	local gate = getControl(ch).gate -- 131
	local a, d, s, r -- 132
	do -- 132
		local _obj_0 = getADSR(ch) -- 132
		a, d, s, r = _obj_0.a, _obj_0.d, _obj_0.s, _obj_0.r -- 132
	end -- 132
	local sustain_level = s * 17 -- 133

	if gate then -- 135
		if state.env_state == ENV_STATE.IDLE or state.env_state == ENV_STATE.RELEASE then -- 136
			state.env_state = ENV_STATE.ATTACK -- 137
		end -- 136
	else -- 139
		state.env_state = ENV_STATE.RELEASE -- 139
	end -- 135

	if state.env_state == ENV_STATE.ATTACK then -- 141
		local duration = ADSR_LOOKUP.ATTACK[a + 1] -- 142
		state.env_level = state.env_level + 255 / duration * SAMPLE_DT -- 143
		if state.env_level >= 255 then -- 144
			state.env_level = 255 -- 145
			state.env_state = ENV_STATE.DECAY -- 146
		end -- 144
	elseif state.env_state == ENV_STATE.DECAY then -- 147
		local duration = ADSR_LOOKUP.DECAY[d + 1] -- 148
		state.env_level = state.env_level - 255 / duration * SAMPLE_DT -- 149
		if state.env_level <= sustain_level then -- 150
			state.env_level = sustain_level -- 151
			state.env_state = ENV_STATE.SUSTAIN -- 152
		end -- 150
	elseif state.env_state == ENV_STATE.SUSTAIN then -- 153
		state.env_level = sustain_level -- 154
	elseif state.env_state == ENV_STATE.RELEASE then -- 155
		local duration = ADSR_LOOKUP.RELEASE[r + 1] -- 156
		state.env_level = state.env_level - 255 / duration * SAMPLE_DT -- 157
		if state.env_level <= 0 then -- 158
			state.env_level = 0 -- 159
			state.env_state = ENV_STATE.IDLE -- 160
		end -- 158
	end -- 141
end -- 129

local processFilter -- 162
processFilter = function(input, lp, bp, hp, resonance) -- 162
	local output = 0 -- 163

	local cutoff = getFilterCutoff() -- 165

	local f = cutoff / 2047 * 0.7 -- 167
	if f > 0.85 then -- 168
		f = 0.85 -- 169
	end -- 168

	local q = 1.0 - resonance / 15 -- 171
	if q < 0.05 then -- 172
		q = 0.05 -- 173
	end -- 172

	local high = input - filter.low - q * filter.band -- 175
	filter.band = filter.band + f * high -- 176
	filter.low = filter.low + f * filter.band -- 177

	if filter.band > 1 then -- 179
		filter.band = 1 -- 179
	elseif filter.band < -1 then -- 180
		filter.band = -1 -- 180
	end -- 179

	if filter.low > 1 then -- 182
		filter.low = 1 -- 182
	elseif filter.low < -1 then -- 183
		filter.low = -1 -- 183
	end -- 182

	if lp then -- 185
		output = output + filter.low -- 185
	end -- 185
	if bp then -- 186
		output = output + filter.band -- 186
	end -- 186
	if hp then -- 187
		output = output + high -- 187
	end -- 187

	return output * 0.8 + input * 0.2 -- 189
end -- 162

local stepOscillators -- 191
stepOscillators = function() -- 191
	local clock = getClock() -- 192
	local dt_clock = clock / SAMPLE_RATE -- 193

	for i = 1, 3 do -- 195
		local state = channels[i] -- 196
		local test = getControl(i).test -- 197

		state.prev_acc = state.acc -- 199
		if test then -- 200
			state.noise_reg = 0xfffff -- 201
			state.acc = 0 -- 202
		else -- 204
			local freq = getFrequency(i) -- 204
			state.acc = (state.acc + freq * dt_clock) % 16777216 -- 205
		end -- 200
	end -- 195

	for i = 1, 3 do -- 207
		local sync = getControl(i).sync -- 208
		if sync then -- 209
			local mod_i -- 210
			if i == 1 then -- 210
				mod_i = 3 -- 210
			else -- 210
				mod_i = i - 1 -- 210
			end -- 210
			if channels[mod_i].acc < channels[mod_i].prev_acc then -- 211
				channels[mod_i].acc = 0 -- 212
			end -- 211
		end -- 209
	end -- 207
end -- 191

local getNoiseSample -- 214
getNoiseSample = function(ch) -- 214
	local state = channels[ch] -- 215
	local acc_i = math.floor(state.acc) -- 216
	local current_bit19 = bit.band(bit.rshift(acc_i, 19), 1) -- 217

	if state.last_bit19 == 0 and current_bit19 == 1 then -- 219
		local reg = state.noise_reg -- 220
		local bit22 = bit.band(bit.rshift(reg, 22), 1) -- 221
		local bit17 = bit.band(bit.rshift(reg, 17), 1) -- 222
		local feedback = bit.bxor(bit22, bit17) -- 223

		reg = bit.band(bit.lshift(reg, 1), 0x7fffff) -- 225
		reg = bit.bor(reg, feedback) -- 226

		state.noise_reg = reg -- 228
	end -- 219
	state.last_bit19 = current_bit19 -- 229

	local r = state.noise_reg -- 231
	local out = 0 -- 232
	out = bit.bor(out, bit.lshift(bit.band(bit.rshift(r, 22), 1), 7)) -- 233
	out = bit.bor(out, bit.lshift(bit.band(bit.rshift(r, 20), 1), 6)) -- 234
	out = bit.bor(out, bit.lshift(bit.band(bit.rshift(r, 16), 1), 5)) -- 235
	out = bit.bor(out, bit.lshift(bit.band(bit.rshift(r, 13), 1), 4)) -- 236
	out = bit.bor(out, bit.lshift(bit.band(bit.rshift(r, 11), 1), 3)) -- 237
	out = bit.bor(out, bit.lshift(bit.band(bit.rshift(r, 7), 1), 2)) -- 238
	out = bit.bor(out, bit.lshift(bit.band(bit.rshift(r, 4), 1), 1)) -- 239
	return bit.bor(out, bit.band(bit.rshift(r, 2), 1)) -- 240
end -- 214

local _anon_func_0 = function() -- 291
	local _exp_0 = 0xff -- 291
	if _exp_0 ~= nil then -- 291
		return _exp_0 -- 291
	else -- 291
		return 0 -- 291
	end -- 291
end -- 291
local getSample -- 242
getSample = function(ch) -- 242
	local state = channels[ch] -- 243
	local mod_i -- 244
	if ch == 1 then -- 244
		mod_i = 3 -- 244
	else -- 244
		mod_i = ch - 1 -- 244
	end -- 244
	local ring, test, tri, saw, pulse, noise -- 245
	do -- 245
		local _obj_0 = getControl(ch) -- 245
		ring, test, tri, saw, pulse, noise = _obj_0.ring, _obj_0.test, _obj_0.tri, _obj_0.saw, _obj_0.pulse, _obj_0.noise -- 245
	end -- 245

	if test then -- 247
		return 0 -- 247
	end -- 247

	local sample_raw = 0xff -- 249
	local any_wave = false -- 250
	local acc_i = math.floor(state.acc) -- 251

	if tri then -- 253
		local raw_tri_acc = acc_i -- 254
		local mod_acc = channels[mod_i].acc -- 255

		if ring then -- 257
			local car_msb = bit.band(bit.rshift(acc_i, 23), 1) -- 258
			local mod_msb = bit.band(bit.rshift(mod_acc, 23), 1) -- 259
			local ring_msb = bit.bxor(car_msb, mod_msb) -- 260

			raw_tri_acc = bit.bor(bit.band(acc_i, 0x7fffff), bit.lshift(ring_msb, 23)) -- 262
		end -- 257

		local msb = bit.band(bit.rshift(raw_tri_acc, 23), 1) -- 267
		local v = bit.band(bit.rshift(raw_tri_acc, 16), 0x7f) -- 268

		if msb == 1 then -- 270
			v = 0x7f - v -- 270
		end -- 270
		sample_raw = bit.band(sample_raw, v * 2) -- 271
		any_wave = true -- 272
	end -- 253
	if saw then -- 273
		local v = bit.band(bit.rshift(acc_i, 16), 0xff) -- 274
		sample_raw = bit.band(sample_raw, v) -- 275
		any_wave = true -- 276
	end -- 273
	if pulse then -- 277
		local pw = getPulseWidth(ch) -- 278
		local acc12 = bit.band(bit.rshift(acc_i, 12), 0xfff) -- 279
		local v = (acc12 < pw) and 0xff or 0x00 -- 280
		sample_raw = bit.band(sample_raw, v) -- 281
		any_wave = true -- 282
	end -- 277
	if noise then -- 283
		local v = getNoiseSample(ch) -- 284
		sample_raw = bit.band(sample_raw, v) -- 285
		any_wave = true -- 286
	end -- 283

	if not any_wave then -- 288
		return 0 -- 288
	end -- 288

	local sample = sample_raw / 127.5 - 1 -- 290
	return sample * state.env_level / _anon_func_0() -- 291
end -- 242

lovesid.update = function(self) -- 293
	self.source:play() -- 294

	while self.source:getFreeBufferCount() > 0 do -- 296
		local sound_data = love.sound.newSoundData(buffer_size, SAMPLE_RATE, 16, 1) -- 297

		local filter_apply = getFilterApply() -- 299
		local filter_pass = getFilterPass() -- 300
		local res = getFilterResonance() -- 301
		local main_vol = getVolume() / 15 -- 302

		for i = 0, buffer_size - 1 do -- 304
			for ch = 1, 3 do -- 305
				updateEnvelope(ch) -- 305
			end -- 305
			stepOscillators() -- 306

			local through_filter = 0 -- 308
			local unfiltered = 0 -- 308
			for ch = 1, 3 do -- 309
				local sample = getSample(ch) / 3 -- 310
				if filter_apply[i] then -- 311
					through_filter = through_filter + sample -- 312
				else -- 314
					unfiltered = unfiltered + sample -- 314
				end -- 311
			end -- 309

			local output = unfiltered + processFilter(through_filter, filter_pass.low_pass, filter_pass.band_pass, filter_pass.high_pass, res) -- 316
			output = output * main_vol -- 317
			sound_data:setSample(i, math.max(-1, math.min(1, output))) -- 318
		end -- 304

		self.source:queue(sound_data) -- 320
	end -- 296
end -- 293

_module_0 = lovesid -- 322
return _module_0 -- 1
