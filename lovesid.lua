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
local sound_buffers = { } -- 24

local _anon_func_0 = function() -- 289
	local _exp_0 = 0xff -- 289
	if _exp_0 ~= nil then -- 289
		return _exp_0 -- 289
	else -- 289
		return 0 -- 289
	end -- 289
end -- 289
local Sid -- 26
local _class_0 -- 26
local _base_0 = { -- 26

	getVolume = function(self) -- 56
		local byte = self.registers[25] -- 57
		return bit.band(byte, 0xf) -- 58
	end, -- 56

	getClock = function(self) -- 60
		return self.is_ntsc and CLOCK.NTSC or CLOCK.PAL -- 60
	end, -- 60

	getChannelOffset = function(self, ch) -- 62
		return (ch - 1) * 7 + 1 -- 62
	end, -- 62

	getControl = function(self, ch) -- 64
		local byte = self.registers[self:getChannelOffset(ch) + 4] -- 65
		return { -- 67
			gate = bit.band(byte, 0x01) ~= 0, -- 67
			sync = bit.band(byte, 0x02) ~= 0, -- 68
			ring = bit.band(byte, 0x04) ~= 0, -- 69
			test = bit.band(byte, 0x08) ~= 0, -- 70
			tri = bit.band(byte, 0x10) ~= 0, -- 71
			saw = bit.band(byte, 0x20) ~= 0, -- 72
			pulse = bit.band(byte, 0x40) ~= 0, -- 73
			noise = bit.band(byte, 0x80) ~= 0 -- 74
		} -- 66
	end, -- 64

	getADSR = function(self, ch) -- 77
		local offset = self:getChannelOffset(ch) + 5 -- 78
		local AD, SR = self.registers[offset], self.registers[offset + 1] -- 79
		return { -- 81
			a = bit.band(bit.rshift(AD, 4), 0xf), -- 81
			d = bit.band(AD, 0xf), -- 82
			s = bit.band(bit.rshift(SR, 4), 0xf), -- 83
			r = bit.band(SR, 0xf) -- 84
		} -- 80
	end, -- 77

	getFrequencyWord = function(self, ch) -- 87
		local offset = self:getChannelOffset(ch) -- 88
		local lo, hi = self.registers[offset], self.registers[offset + 1] -- 89
		return bit.bor(bit.lshift(hi, 8), lo) -- 90
	end, -- 87

	freqWordToHz = function(self, word) -- 92
		return word * self:getClock() / 16777216 -- 92
	end, -- 92

	getPulseWidth = function(self, ch) -- 94
		local offset = self:getChannelOffset(ch) + 2 -- 95
		local lo, hi = self.registers[offset], bit.band(self.registers[offset + 1], 0xf) -- 96
		local _exp_0 = bit.bor(bit.lshift(hi, 8), lo) -- 97
		if _exp_0 ~= nil then -- 97
			return _exp_0 -- 97
		else -- 97
			return 0 -- 97
		end -- 97
	end, -- 94

	getFilterCutoff = function(self) -- 99
		local lo, hi = bit.band(self.registers[22], 0x7), self.registers[23] -- 100
		return bit.bor(lo, bit.lshift(hi, 3)) -- 101
	end, -- 99

	getFilterResonance = function(self) -- 103
		local byte = self.registers[24] -- 104
		return bit.band(bit.rshift(byte, 4), 0xf) -- 105
	end, -- 103

	getFilterApply = function(self) -- 107
		local byte = self.registers[24] -- 108
		return { -- 110
			bit.band(byte, 0x1) ~= 0, -- 110
			bit.band(byte, 0x2) ~= 0, -- 111
			bit.band(byte, 0x4) ~= 0 -- 112
		} -- 109
	end, -- 107

	getFilterPass = function(self) -- 115
		local byte = self.registers[25] -- 116
		return { -- 118
			low_pass = bit.band(byte, 0x10) ~= 0, -- 118
			band_pass = bit.band(byte, 0x20) ~= 0, -- 119
			high_pass = bit.band(byte, 0x40) ~= 0 -- 120
		} -- 117
	end, -- 115

	getChannel3Off = function(self) -- 123
		local byte = self.registers[25] -- 124
		return bit.band(byte, 0x80) == 0x80 -- 125
	end, -- 123

	updateEnvelope = function(self, ch) -- 127
		local state = channels[self][ch] -- 128
		local gate = self:getControl(ch).gate -- 129
		local a, d, s, r -- 130
		do -- 130
			local _obj_0 = self:getADSR(ch) -- 130
			a, d, s, r = _obj_0.a, _obj_0.d, _obj_0.s, _obj_0.r -- 130
		end -- 130
		local sustain_level = s * 17 -- 131

		if gate then -- 133
			if state.env_state == ENV_STATE.IDLE or state.env_state == ENV_STATE.RELEASE then -- 134
				state.env_state = ENV_STATE.ATTACK -- 135
			end -- 134
		else -- 137
			state.env_state = ENV_STATE.RELEASE -- 137
		end -- 133

		if state.env_state == ENV_STATE.ATTACK then -- 139
			local duration = ADSR_LOOKUP.ATTACK[a + 1] -- 140
			state.env_level = state.env_level + 255 / duration * SAMPLE_DT -- 141
			if state.env_level >= 255 then -- 142
				state.env_level = 255 -- 143
				state.env_state = ENV_STATE.DECAY -- 144
			end -- 142
		elseif state.env_state == ENV_STATE.DECAY then -- 145
			local duration = ADSR_LOOKUP.DECAY[d + 1] -- 146
			state.env_level = state.env_level - 255 / duration * SAMPLE_DT -- 147
			if state.env_level <= sustain_level then -- 148
				state.env_level = sustain_level -- 149
				state.env_state = ENV_STATE.SUSTAIN -- 150
			end -- 148
		elseif state.env_state == ENV_STATE.SUSTAIN then -- 151
			state.env_level = sustain_level -- 152
		elseif state.env_state == ENV_STATE.RELEASE then -- 153
			local duration = ADSR_LOOKUP.RELEASE[r + 1] -- 154
			state.env_level = state.env_level - 255 / duration * SAMPLE_DT -- 155
			if state.env_level <= 0 then -- 156
				state.env_level = 0 -- 157
				state.env_state = ENV_STATE.IDLE -- 158
			end -- 156
		end -- 139
	end, -- 127

	processFilter = function(self, input, lp, bp, hp, resonance) -- 160
		local output = 0 -- 161

		local cutoff = self:getFilterCutoff() -- 163

		local f = cutoff / 2047 * 0.7 -- 165
		if f > 0.85 then -- 166
			f = 0.85 -- 167
		end -- 166

		local q = 1.0 - resonance / 15 -- 169
		if q < 0.05 then -- 170
			q = 0.05 -- 171
		end -- 170

		local high = input - filters[self].low - q * filters[self].band -- 173
		filters[self].band = filters[self].band + f * high -- 174
		filters[self].low = filters[self].low + f * filters[self].band -- 175

		if filters[self].band > 1 then -- 177
			filters[self].band = 1 -- 177
		elseif filters[self].band < -1 then -- 178
			filters[self].band = -1 -- 178
		end -- 177

		if filters[self].low > 1 then -- 180
			filters[self].low = 1 -- 180
		elseif filters[self].low < -1 then -- 181
			filters[self].low = -1 -- 181
		end -- 180

		if lp then -- 183
			output = output + filters[self].low -- 183
		end -- 183
		if bp then -- 184
			output = output + filters[self].band -- 184
		end -- 184
		if hp then -- 185
			output = output + high -- 185
		end -- 185

		return output * 0.8 + input * 0.2 -- 187
	end, -- 160

	stepOscillators = function(self) -- 189
		local clock = self:getClock() -- 190
		local dt_clock = clock / SAMPLE_RATE -- 191

		for i = 1, 3 do -- 193
			local state = channels[self][i] -- 194
			local test = self:getControl(i).test -- 195

			state.prev_acc = state.acc -- 197
			if test then -- 198
				state.noise_reg = 0xfffff -- 199
				state.acc = 0 -- 200
			else -- 202
				local freq = self:getFrequencyWord(i) -- 202
				state.acc = (state.acc + freq * dt_clock) % 16777216 -- 203
			end -- 198
		end -- 193

		for i = 1, 3 do -- 205
			local sync = self:getControl(i).sync -- 206
			if sync then -- 207
				local mod_i -- 208
				if i == 1 then -- 208
					mod_i = 3 -- 208
				else -- 208
					mod_i = i - 1 -- 208
				end -- 208
				if channels[self][mod_i].acc < channels[self][mod_i].prev_acc then -- 209
					channels[self][mod_i].acc = 0 -- 210
				end -- 209
			end -- 207
		end -- 205
	end, -- 189

	getNoiseSample = function(self, ch) -- 212
		local state = channels[self][ch] -- 213
		local acc_i = math.floor(state.acc) -- 214
		local current_bit19 = bit.band(bit.rshift(acc_i, 19), 1) -- 215

		if state.last_bit19 == 0 and current_bit19 == 1 then -- 217
			local reg = state.noise_reg -- 218
			local bit22 = bit.band(bit.rshift(reg, 22), 1) -- 219
			local bit17 = bit.band(bit.rshift(reg, 17), 1) -- 220
			local feedback = bit.bxor(bit22, bit17) -- 221

			reg = bit.band(bit.lshift(reg, 1), 0x7fffff) -- 223
			reg = bit.bor(reg, feedback) -- 224

			state.noise_reg = reg -- 226
		end -- 217
		state.last_bit19 = current_bit19 -- 227

		local r = state.noise_reg -- 229
		local out = 0 -- 230
		out = bit.bor(out, bit.lshift(bit.band(bit.rshift(r, 22), 1), 7)) -- 231
		out = bit.bor(out, bit.lshift(bit.band(bit.rshift(r, 20), 1), 6)) -- 232
		out = bit.bor(out, bit.lshift(bit.band(bit.rshift(r, 16), 1), 5)) -- 233
		out = bit.bor(out, bit.lshift(bit.band(bit.rshift(r, 13), 1), 4)) -- 234
		out = bit.bor(out, bit.lshift(bit.band(bit.rshift(r, 11), 1), 3)) -- 235
		out = bit.bor(out, bit.lshift(bit.band(bit.rshift(r, 7), 1), 2)) -- 236
		out = bit.bor(out, bit.lshift(bit.band(bit.rshift(r, 4), 1), 1)) -- 237
		return bit.bor(out, bit.band(bit.rshift(r, 2), 1)) -- 238
	end, -- 212

	getSample = function(self, ch) -- 240
		local state = channels[self][ch] -- 241
		local mod_i -- 242
		if ch == 1 then -- 242
			mod_i = 3 -- 242
		else -- 242
			mod_i = ch - 1 -- 242
		end -- 242
		local ring, test, tri, saw, pulse, noise -- 243
		do -- 243
			local _obj_0 = self:getControl(ch) -- 243
			ring, test, tri, saw, pulse, noise = _obj_0.ring, _obj_0.test, _obj_0.tri, _obj_0.saw, _obj_0.pulse, _obj_0.noise -- 243
		end -- 243

		if test then -- 245
			return 0 -- 245
		end -- 245

		local sample_raw = 0xff -- 247
		local any_wave = false -- 248
		local acc_i = math.floor(state.acc) -- 249

		if tri then -- 251
			local raw_tri_acc = acc_i -- 252
			local mod_acc = channels[self][mod_i].acc -- 253

			if ring then -- 255
				local car_msb = bit.band(bit.rshift(acc_i, 23), 1) -- 256
				local mod_msb = bit.band(bit.rshift(mod_acc, 23), 1) -- 257
				local ring_msb = bit.bxor(car_msb, mod_msb) -- 258

				raw_tri_acc = bit.bor(bit.band(acc_i, 0x7fffff), bit.lshift(ring_msb, 23)) -- 260
			end -- 255

			local msb = bit.band(bit.rshift(raw_tri_acc, 23), 1) -- 265
			local v = bit.band(bit.rshift(raw_tri_acc, 16), 0x7f) -- 266

			if msb == 1 then -- 268
				v = 0x7f - v -- 268
			end -- 268
			sample_raw = bit.band(sample_raw, v * 2) -- 269
			any_wave = true -- 270
		end -- 251
		if saw then -- 271
			local v = bit.band(bit.rshift(acc_i, 16), 0xff) -- 272
			sample_raw = bit.band(sample_raw, v) -- 273
			any_wave = true -- 274
		end -- 271
		if pulse then -- 275
			local pw = self:getPulseWidth(ch) -- 276
			local acc12 = bit.band(bit.rshift(acc_i, 12), 0xfff) -- 277
			local v = (acc12 < pw) and 0xff or 0x00 -- 278
			sample_raw = bit.band(sample_raw, v) -- 279
			any_wave = true -- 280
		end -- 275
		if noise then -- 281
			local v = self:getNoiseSample(ch) -- 282
			sample_raw = bit.band(sample_raw, v) -- 283
			any_wave = true -- 284
		end -- 281

		if not any_wave then -- 286
			return 0 -- 286
		end -- 286

		local sample = sample_raw / 127.5 - 1 -- 288
		return sample * state.env_level / _anon_func_0() -- 289
	end, -- 240

	update = function(self) -- 291
		self.source:play() -- 292

		while self.source:getFreeBufferCount() > 0 do -- 294
			local sound_buffer = sound_buffers[self] -- 295

			local filter_apply = self:getFilterApply() -- 297
			local filter_pass = self:getFilterPass() -- 298
			local res = self:getFilterResonance() -- 299
			local main_vol = self:getVolume() / 15 -- 300

			for i = 0, self.buffer_size - 1 do -- 302
				for ch = 1, 3 do -- 303
					self:updateEnvelope(ch) -- 303
				end -- 303
				self:stepOscillators() -- 304

				local through_filter = 0 -- 306
				local unfiltered = 0 -- 306
				for ch = 1, 3 do -- 307
					local sample = self:getSample(ch) / 3 -- 308
					if filter_apply[ch] then -- 309
						through_filter = through_filter + sample -- 310
					else -- 312
						unfiltered = unfiltered + sample -- 312
					end -- 309
				end -- 307

				local output = unfiltered + self:processFilter(through_filter, filter_pass.low_pass, filter_pass.band_pass, filter_pass.high_pass, res) -- 314
				output = output * main_vol -- 315
				sound_buffer:setSample(i, math.max(-1, math.min(1, output))) -- 316
			end -- 302

			self.source:queue(sound_buffer) -- 318
		end -- 294
	end -- 291
} -- 26
if _base_0.__index == nil then -- 26
	_base_0.__index = _base_0 -- 26
end -- 26
_class_0 = setmetatable({ -- 26
	__init = function(self, buffer_size, buffer_count, is_ntsc) -- 27
		if buffer_size == nil then -- 27
			buffer_size = 1024 -- 27
		end -- 27
		if buffer_count == nil then -- 27
			buffer_count = 8 -- 27
		end -- 27
		if is_ntsc == nil then -- 27
			is_ntsc = false -- 27
		end -- 27
		self.buffer_size = buffer_size -- 28
		self.buffer_count = buffer_count -- 29
		self.is_ntsc = is_ntsc -- 30

		self.registers = setmetatable({ }, { -- 33
			__index = function() -- 33
				return 0 -- 33
			end, -- 33
			__newindex = function(self, k, v) -- 34
				if 1 <= k and k <= 25 then -- 35
					return rawset(self, k, bit.band(v, 0xff)) -- 35
				end -- 35
			end -- 34
		}) -- 32
		setmetatable(self, { -- 38
			__index = function(self, k) -- 38
				if type(k) == "number" then -- 39
					return self.registers[k] -- 40
				else -- 42
					return Sid[k] -- 42
				end -- 39
			end, -- 38
			__newindex = function(self, k, v) -- 43
				if type(k) == "number" then -- 44
					self.registers[k] = v -- 45
				else -- 47
					return rawset(self, k, v) -- 47
				end -- 44
			end -- 43
		}) -- 37
		do -- 49
			local _accum_0 = { } -- 49
			local _len_0 = 1 -- 49
			for i = 1, 3 do -- 49
				_accum_0[_len_0] = { -- 50
					acc = 0.0, -- 50
					prev_acc = 0.0, -- 50
					env_level = 0, -- 50
					env_state = ENV_STATE.IDLE, -- 50
					noise_reg = 0xfffff, -- 50
					last_bit19 = 0 -- 50
				} -- 50
				_len_0 = _len_0 + 1 -- 50
			end -- 49
			channels[self] = _accum_0 -- 49
		end -- 49
		filters[self] = { -- 51
			low = 0, -- 51
			band = 0 -- 51
		} -- 51
		sound_buffers[self] = love.sound.newSoundData(self.buffer_size, SAMPLE_RATE, 16, 1) -- 52

		self.source = love.audio.newQueueableSource(SAMPLE_RATE, 16, 1, self.buffer_count) -- 54
	end, -- 27
	__base = _base_0, -- 26
	__name = "Sid" -- 26
}, { -- 26
	__index = _base_0, -- 26
	__call = function(cls, ...) -- 26
		local _self_0 = setmetatable({ }, _base_0) -- 26
		cls.__init(_self_0, ...) -- 26
		return _self_0 -- 26
	end -- 26
}) -- 26
_base_0.__class = _class_0 -- 26
Sid = _class_0 -- 26
_module_0 = _class_0 -- 26
return _module_0 -- 1
