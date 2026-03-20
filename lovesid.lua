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
local channels = { } -- 22
local filters = { } -- 23

local _anon_func_0 = function() -- 287
	local _exp_0 = 0xff -- 287
	if _exp_0 ~= nil then -- 287
		return _exp_0 -- 287
	else -- 287
		return 0 -- 287
	end -- 287
end -- 287
local Sid -- 25
local _class_0 -- 25
local _base_0 = { -- 25

	getVolume = function(self) -- 54
		local byte = self.registers[25] -- 55
		return bit.band(byte, 0xf) -- 56
	end, -- 54

	getClock = function(self) -- 58
		return self.is_ntsc and CLOCK.NTSC or CLOCK.PAL -- 58
	end, -- 58

	getChannelOffset = function(self, ch) -- 60
		return (ch - 1) * 7 + 1 -- 60
	end, -- 60

	getControl = function(self, ch) -- 62
		local byte = self.registers[self:getChannelOffset(ch) + 4] -- 63
		return { -- 65
			gate = bit.band(byte, 0x01) ~= 0, -- 65
			sync = bit.band(byte, 0x02) ~= 0, -- 66
			ring = bit.band(byte, 0x04) ~= 0, -- 67
			test = bit.band(byte, 0x08) ~= 0, -- 68
			tri = bit.band(byte, 0x10) ~= 0, -- 69
			saw = bit.band(byte, 0x20) ~= 0, -- 70
			pulse = bit.band(byte, 0x40) ~= 0, -- 71
			noise = bit.band(byte, 0x80) ~= 0 -- 72
		} -- 64
	end, -- 62

	getADSR = function(self, ch) -- 75
		local offset = self:getChannelOffset(ch) + 5 -- 76
		local AD, SR = self.registers[offset], self.registers[offset + 1] -- 77
		return { -- 79
			a = bit.band(bit.rshift(AD, 4), 0xf), -- 79
			d = bit.band(AD, 0xf), -- 80
			s = bit.band(bit.rshift(SR, 4), 0xf), -- 81
			r = bit.band(SR, 0xf) -- 82
		} -- 78
	end, -- 75

	getFrequencyWord = function(self, ch) -- 85
		local offset = self:getChannelOffset(ch) -- 86
		local lo, hi = self.registers[offset], self.registers[offset + 1] -- 87
		return bit.bor(bit.lshift(hi, 8), lo) -- 88
	end, -- 85

	freqWordToHz = function(self, word) -- 90
		return word * self:getClock() / 16777216 -- 90
	end, -- 90

	getPulseWidth = function(self, ch) -- 92
		local offset = self:getChannelOffset(ch) + 2 -- 93
		local lo, hi = self.registers[offset], bit.band(self.registers[offset + 1], 0xf) -- 94
		local _exp_0 = bit.bor(bit.lshift(hi, 8), lo) -- 95
		if _exp_0 ~= nil then -- 95
			return _exp_0 -- 95
		else -- 95
			return 0 -- 95
		end -- 95
	end, -- 92

	getFilterCutoff = function(self) -- 97
		local lo, hi = bit.band(self.registers[22], 0x7), self.registers[23] -- 98
		return bit.bor(lo, bit.lshift(hi, 3)) -- 99
	end, -- 97

	getFilterResonance = function(self) -- 101
		local byte = self.registers[24] -- 102
		return bit.band(bit.rshift(byte, 4), 0xf) -- 103
	end, -- 101

	getFilterApply = function(self) -- 105
		local byte = self.registers[24] -- 106
		return { -- 108
			bit.band(byte, 0x1) ~= 0, -- 108
			bit.band(byte, 0x2) ~= 0, -- 109
			bit.band(byte, 0x4) ~= 0 -- 110
		} -- 107
	end, -- 105

	getFilterPass = function(self) -- 113
		local byte = self.registers[25] -- 114
		return { -- 116
			low_pass = bit.band(byte, 0x10) ~= 0, -- 116
			band_pass = bit.band(byte, 0x20) ~= 0, -- 117
			high_pass = bit.band(byte, 0x40) ~= 0 -- 118
		} -- 115
	end, -- 113

	getChannel3Off = function(self) -- 121
		local byte = self.registers[25] -- 122
		return bit.band(byte, 0x80) == 0x80 -- 123
	end, -- 121

	updateEnvelope = function(self, ch) -- 125
		local state = channels[self][ch] -- 126
		local gate = self:getControl(ch).gate -- 127
		local a, d, s, r -- 128
		do -- 128
			local _obj_0 = self:getADSR(ch) -- 128
			a, d, s, r = _obj_0.a, _obj_0.d, _obj_0.s, _obj_0.r -- 128
		end -- 128
		local sustain_level = s * 17 -- 129

		if gate then -- 131
			if state.env_state == ENV_STATE.IDLE or state.env_state == ENV_STATE.RELEASE then -- 132
				state.env_state = ENV_STATE.ATTACK -- 133
			end -- 132
		else -- 135
			state.env_state = ENV_STATE.RELEASE -- 135
		end -- 131

		if state.env_state == ENV_STATE.ATTACK then -- 137
			local duration = ADSR_LOOKUP.ATTACK[a + 1] -- 138
			state.env_level = state.env_level + 255 / duration * SAMPLE_DT -- 139
			if state.env_level >= 255 then -- 140
				state.env_level = 255 -- 141
				state.env_state = ENV_STATE.DECAY -- 142
			end -- 140
		elseif state.env_state == ENV_STATE.DECAY then -- 143
			local duration = ADSR_LOOKUP.DECAY[d + 1] -- 144
			state.env_level = state.env_level - 255 / duration * SAMPLE_DT -- 145
			if state.env_level <= sustain_level then -- 146
				state.env_level = sustain_level -- 147
				state.env_state = ENV_STATE.SUSTAIN -- 148
			end -- 146
		elseif state.env_state == ENV_STATE.SUSTAIN then -- 149
			state.env_level = sustain_level -- 150
		elseif state.env_state == ENV_STATE.RELEASE then -- 151
			local duration = ADSR_LOOKUP.RELEASE[r + 1] -- 152
			state.env_level = state.env_level - 255 / duration * SAMPLE_DT -- 153
			if state.env_level <= 0 then -- 154
				state.env_level = 0 -- 155
				state.env_state = ENV_STATE.IDLE -- 156
			end -- 154
		end -- 137
	end, -- 125

	processFilter = function(self, input, lp, bp, hp, resonance) -- 158
		local output = 0 -- 159

		local cutoff = self:getFilterCutoff() -- 161

		local f = cutoff / 2047 * 0.7 -- 163
		if f > 0.85 then -- 164
			f = 0.85 -- 165
		end -- 164

		local q = 1.0 - resonance / 15 -- 167
		if q < 0.05 then -- 168
			q = 0.05 -- 169
		end -- 168

		local high = input - filters[self].low - q * filters[self].band -- 171
		filters[self].band = filters[self].band + f * high -- 172
		filters[self].low = filters[self].low + f * filters[self].band -- 173

		if filters[self].band > 1 then -- 175
			filters[self].band = 1 -- 175
		elseif filters[self].band < -1 then -- 176
			filters[self].band = -1 -- 176
		end -- 175

		if filters[self].low > 1 then -- 178
			filters[self].low = 1 -- 178
		elseif filters[self].low < -1 then -- 179
			filters[self].low = -1 -- 179
		end -- 178

		if lp then -- 181
			output = output + filters[self].low -- 181
		end -- 181
		if bp then -- 182
			output = output + filters[self].band -- 182
		end -- 182
		if hp then -- 183
			output = output + high -- 183
		end -- 183

		return output * 0.8 + input * 0.2 -- 185
	end, -- 158

	stepOscillators = function(self) -- 187
		local clock = self:getClock() -- 188
		local dt_clock = clock / SAMPLE_RATE -- 189

		for i = 1, 3 do -- 191
			local state = channels[self][i] -- 192
			local test = self:getControl(i).test -- 193

			state.prev_acc = state.acc -- 195
			if test then -- 196
				state.noise_reg = 0xfffff -- 197
				state.acc = 0 -- 198
			else -- 200
				local freq = self:getFrequencyWord(i) -- 200
				state.acc = (state.acc + freq * dt_clock) % 16777216 -- 201
			end -- 196
		end -- 191

		for i = 1, 3 do -- 203
			local sync = self:getControl(i).sync -- 204
			if sync then -- 205
				local mod_i -- 206
				if i == 1 then -- 206
					mod_i = 3 -- 206
				else -- 206
					mod_i = i - 1 -- 206
				end -- 206
				if channels[self][mod_i].acc < channels[self][mod_i].prev_acc then -- 207
					channels[self][mod_i].acc = 0 -- 208
				end -- 207
			end -- 205
		end -- 203
	end, -- 187

	getNoiseSample = function(self, ch) -- 210
		local state = channels[self][ch] -- 211
		local acc_i = math.floor(state.acc) -- 212
		local current_bit19 = bit.band(bit.rshift(acc_i, 19), 1) -- 213

		if state.last_bit19 == 0 and current_bit19 == 1 then -- 215
			local reg = state.noise_reg -- 216
			local bit22 = bit.band(bit.rshift(reg, 22), 1) -- 217
			local bit17 = bit.band(bit.rshift(reg, 17), 1) -- 218
			local feedback = bit.bxor(bit22, bit17) -- 219

			reg = bit.band(bit.lshift(reg, 1), 0x7fffff) -- 221
			reg = bit.bor(reg, feedback) -- 222

			state.noise_reg = reg -- 224
		end -- 215
		state.last_bit19 = current_bit19 -- 225

		local r = state.noise_reg -- 227
		local out = 0 -- 228
		out = bit.bor(out, bit.lshift(bit.band(bit.rshift(r, 22), 1), 7)) -- 229
		out = bit.bor(out, bit.lshift(bit.band(bit.rshift(r, 20), 1), 6)) -- 230
		out = bit.bor(out, bit.lshift(bit.band(bit.rshift(r, 16), 1), 5)) -- 231
		out = bit.bor(out, bit.lshift(bit.band(bit.rshift(r, 13), 1), 4)) -- 232
		out = bit.bor(out, bit.lshift(bit.band(bit.rshift(r, 11), 1), 3)) -- 233
		out = bit.bor(out, bit.lshift(bit.band(bit.rshift(r, 7), 1), 2)) -- 234
		out = bit.bor(out, bit.lshift(bit.band(bit.rshift(r, 4), 1), 1)) -- 235
		return bit.bor(out, bit.band(bit.rshift(r, 2), 1)) -- 236
	end, -- 210

	getSample = function(self, ch) -- 238
		local state = channels[self][ch] -- 239
		local mod_i -- 240
		if ch == 1 then -- 240
			mod_i = 3 -- 240
		else -- 240
			mod_i = ch - 1 -- 240
		end -- 240
		local ring, test, tri, saw, pulse, noise -- 241
		do -- 241
			local _obj_0 = self:getControl(ch) -- 241
			ring, test, tri, saw, pulse, noise = _obj_0.ring, _obj_0.test, _obj_0.tri, _obj_0.saw, _obj_0.pulse, _obj_0.noise -- 241
		end -- 241

		if test then -- 243
			return 0 -- 243
		end -- 243

		local sample_raw = 0xff -- 245
		local any_wave = false -- 246
		local acc_i = math.floor(state.acc) -- 247

		if tri then -- 249
			local raw_tri_acc = acc_i -- 250
			local mod_acc = channels[self][mod_i].acc -- 251

			if ring then -- 253
				local car_msb = bit.band(bit.rshift(acc_i, 23), 1) -- 254
				local mod_msb = bit.band(bit.rshift(mod_acc, 23), 1) -- 255
				local ring_msb = bit.bxor(car_msb, mod_msb) -- 256

				raw_tri_acc = bit.bor(bit.band(acc_i, 0x7fffff), bit.lshift(ring_msb, 23)) -- 258
			end -- 253

			local msb = bit.band(bit.rshift(raw_tri_acc, 23), 1) -- 263
			local v = bit.band(bit.rshift(raw_tri_acc, 16), 0x7f) -- 264

			if msb == 1 then -- 266
				v = 0x7f - v -- 266
			end -- 266
			sample_raw = bit.band(sample_raw, v * 2) -- 267
			any_wave = true -- 268
		end -- 249
		if saw then -- 269
			local v = bit.band(bit.rshift(acc_i, 16), 0xff) -- 270
			sample_raw = bit.band(sample_raw, v) -- 271
			any_wave = true -- 272
		end -- 269
		if pulse then -- 273
			local pw = self:getPulseWidth(ch) -- 274
			local acc12 = bit.band(bit.rshift(acc_i, 12), 0xfff) -- 275
			local v = (acc12 < pw) and 0xff or 0x00 -- 276
			sample_raw = bit.band(sample_raw, v) -- 277
			any_wave = true -- 278
		end -- 273
		if noise then -- 279
			local v = self:getNoiseSample(ch) -- 280
			sample_raw = bit.band(sample_raw, v) -- 281
			any_wave = true -- 282
		end -- 279

		if not any_wave then -- 284
			return 0 -- 284
		end -- 284

		local sample = sample_raw / 127.5 - 1 -- 286
		return sample * state.env_level / _anon_func_0() -- 287
	end, -- 238

	update = function(self) -- 289
		self.source:play() -- 290

		while self.source:getFreeBufferCount() > 0 do -- 292
			local sound_data = love.sound.newSoundData(self.buffer_size, SAMPLE_RATE, 16, 1) -- 293

			local filter_apply = self:getFilterApply() -- 295
			local filter_pass = self:getFilterPass() -- 296
			local res = self:getFilterResonance() -- 297
			local main_vol = self:getVolume() / 15 -- 298

			for i = 0, self.buffer_size - 1 do -- 300
				for ch = 1, 3 do -- 301
					self:updateEnvelope(ch) -- 301
				end -- 301
				self:stepOscillators() -- 302

				local through_filter = 0 -- 304
				local unfiltered = 0 -- 304
				for ch = 1, 3 do -- 305
					local sample = self:getSample(ch) / 3 -- 306
					if filter_apply[ch] then -- 307
						through_filter = through_filter + sample -- 308
					else -- 310
						unfiltered = unfiltered + sample -- 310
					end -- 307
				end -- 305

				local output = unfiltered + self:processFilter(through_filter, filter_pass.low_pass, filter_pass.band_pass, filter_pass.high_pass, res) -- 312
				output = output * main_vol -- 313
				sound_data:setSample(i, math.max(-1, math.min(1, output))) -- 314
			end -- 300

			self.source:queue(sound_data) -- 316
		end -- 292
	end -- 289
} -- 25
if _base_0.__index == nil then -- 25
	_base_0.__index = _base_0 -- 25
end -- 25
_class_0 = setmetatable({ -- 25
	__init = function(self, buffer_size, buffer_count, is_ntsc) -- 26
		if buffer_size ~= nil then -- 27
			self.buffer_size = buffer_size -- 27
		else -- 27
			self.buffer_size = 1024 -- 27
		end -- 27
		if buffer_count ~= nil then -- 28
			self.buffer_count = buffer_count -- 28
		else -- 28
			self.buffer_count = 8 -- 28
		end -- 28
		if is_ntsc ~= nil then -- 29
			self.is_ntsc = is_ntsc -- 29
		else -- 29
			self.is_ntsc = false -- 29
		end -- 29

		self.registers = setmetatable({ }, { -- 32
			__index = function() -- 32
				return 0 -- 32
			end, -- 32
			__newindex = function(self, k, v) -- 33
				if 1 <= k and k <= 25 then -- 34
					return rawset(self, k, bit.band(v, 0xff)) -- 34
				end -- 34
			end -- 33
		}) -- 31
		setmetatable(self, { -- 37
			__index = function(self, k) -- 37
				if type(k) == "number" then -- 38
					return self.registers[k] -- 39
				else -- 41
					return Sid[k] -- 41
				end -- 38
			end, -- 37
			__newindex = function(self, k, v) -- 42
				if type(k) == "number" then -- 43
					self.registers[k] = v -- 44
				else -- 46
					return rawset(self, k, v) -- 46
				end -- 43
			end -- 42
		}) -- 36
		do -- 48
			local _accum_0 = { } -- 48
			local _len_0 = 1 -- 48
			for i = 1, 3 do -- 48
				_accum_0[_len_0] = { -- 49
					acc = 0.0, -- 49
					prev_acc = 0.0, -- 49
					env_level = 0, -- 49
					env_state = ENV_STATE.IDLE, -- 49
					noise_reg = 0xfffff, -- 49
					last_bit19 = 0 -- 49
				} -- 49
				_len_0 = _len_0 + 1 -- 49
			end -- 48
			channels[self] = _accum_0 -- 48
		end -- 48
		filters[self] = { -- 50
			low = 0, -- 50
			band = 0 -- 50
		} -- 50

		self.source = love.audio.newQueueableSource(SAMPLE_RATE, 16, 1, self.buffer_count) -- 52
	end, -- 26
	__base = _base_0, -- 25
	__name = "Sid" -- 25
}, { -- 25
	__index = _base_0, -- 25
	__call = function(cls, ...) -- 25
		local _self_0 = setmetatable({ }, _base_0) -- 25
		cls.__init(_self_0, ...) -- 25
		return _self_0 -- 25
	end -- 25
}) -- 25
_base_0.__class = _class_0 -- 25
Sid = _class_0 -- 25
_module_0 = _class_0 -- 25
return _module_0 -- 1
