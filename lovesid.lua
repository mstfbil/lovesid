-- [yue]: lovesid.yue
local _module_0 = { } -- 1
-- lovesid
-- Copyright (c) 2026 Mustafa Bildirici @mstfbil (voltie_dev)
-- Licensed under the MIT License

local bit = require("bit") -- 5

-- define constants
local CLOCK = { -- 9
	PAL = 985248, -- 9
	NTSC = 1022727 -- 10
} -- 8
local SAMPLE_RATE = 44100 -- 11
local SAMPLE_DT = 1 / SAMPLE_RATE -- 12
local ADSR_LOOKUP = { -- 14
	ATTACK = { -- 14
		0.002, -- 14
		0.008, -- 14
		0.016, -- 14
		0.024, -- 14
		0.038, -- 14
		0.056, -- 14
		0.068, -- 14
		0.080, -- 14
		0.100, -- 14
		0.250, -- 14
		0.500, -- 14
		0.800, -- 14
		1.000, -- 14
		3.000, -- 14
		5.000, -- 14
		8.000 -- 14
	}, -- 14
	DECAY = { -- 15
		0.006, -- 15
		0.024, -- 15
		0.048, -- 15
		0.072, -- 15
		0.114, -- 15
		0.168, -- 15
		0.204, -- 15
		0.240, -- 15
		0.300, -- 15
		0.750, -- 15
		1.500, -- 15
		2.400, -- 15
		3.000, -- 15
		9.000, -- 15
		15.00, -- 15
		24.00 -- 15
	}, -- 15
	RELEASE = { -- 16
		0.006, -- 16
		0.024, -- 16
		0.048, -- 16
		0.072, -- 16
		0.114, -- 16
		0.168, -- 16
		0.204, -- 16
		0.240, -- 16
		0.300, -- 16
		0.750, -- 16
		1.500, -- 16
		2.400, -- 16
		3.000, -- 16
		9.000, -- 16
		15.00, -- 16
		24.00 -- 16
	} -- 16
} -- 13
---@enum ENV_STATE
local ENV_STATE = { -- 19
	IDLE = 1, -- 19
	ATTACK = 2, -- 20
	DECAY = 3, -- 21
	SUSTAIN = 4, -- 22
	RELEASE = 5 -- 23
} -- 18

-- define classes
local _anon_func_0 = function() -- 291
	local _exp_0 = 0xff -- 291
	if _exp_0 ~= nil then -- 291
		return _exp_0 -- 291
	else -- 291
		return 0 -- 291
	end -- 291
end -- 291
local Sid -- 26
do -- 26
	local _class_0 -- 26
	local _base_0 = { -- 26

		getVolume = function(self) -- 55
			local byte = self.registers[25] -- 56
			return bit.band(byte, 0xf) -- 57
		end, -- 55

		getClock = function(self) -- 59
			return self.is_ntsc and CLOCK.NTSC or CLOCK.PAL -- 59
		end, -- 59

		getChannelOffset = function(self, ch) -- 61
			return (ch - 1) * 7 + 1 -- 61
		end, -- 61

		getControl = function(self, ch) -- 63
			local byte = self.registers[self:getChannelOffset(ch) + 4] -- 64
			return { -- 66
				gate = bit.band(byte, 0x01) ~= 0, -- 66
				sync = bit.band(byte, 0x02) ~= 0, -- 67
				ring = bit.band(byte, 0x04) ~= 0, -- 68
				test = bit.band(byte, 0x08) ~= 0, -- 69
				tri = bit.band(byte, 0x10) ~= 0, -- 70
				saw = bit.band(byte, 0x20) ~= 0, -- 71
				pulse = bit.band(byte, 0x40) ~= 0, -- 72
				noise = bit.band(byte, 0x80) ~= 0 -- 73
			} -- 65
		end, -- 63

		getADSR = function(self, ch) -- 76
			local offset = self:getChannelOffset(ch) + 5 -- 77
			local AD, SR = self.registers[offset], self.registers[offset + 1] -- 78
			return { -- 80
				a = bit.band(bit.rshift(AD, 4), 0xf), -- 80
				d = bit.band(AD, 0xf), -- 81
				s = bit.band(bit.rshift(SR, 4), 0xf), -- 82
				r = bit.band(SR, 0xf) -- 83
			} -- 79
		end, -- 76

		getFrequencyWord = function(self, ch) -- 86
			local offset = self:getChannelOffset(ch) -- 87
			local lo, hi = self.registers[offset], self.registers[offset + 1] -- 88
			return bit.bor(bit.lshift(hi, 8), lo) -- 89
		end, -- 86

		freqWordToHz = function(self, word) -- 91
			return word * self:getClock() / 16777216 -- 91
		end, -- 91

		getPulseWidth = function(self, ch) -- 93
			local offset = self:getChannelOffset(ch) + 2 -- 94
			local lo, hi = self.registers[offset], bit.band(self.registers[offset + 1], 0xf) -- 95
			local _exp_0 = bit.bor(bit.lshift(hi, 8), lo) -- 96
			if _exp_0 ~= nil then -- 96
				return _exp_0 -- 96
			else -- 96
				return 0 -- 96
			end -- 96
		end, -- 93

		getFilterCutoff = function(self) -- 98
			local lo, hi = bit.band(self.registers[22], 0x7), self.registers[23] -- 99
			return bit.bor(lo, bit.lshift(hi, 3)) -- 100
		end, -- 98

		getFilterResonance = function(self) -- 102
			local byte = self.registers[24] -- 103
			return bit.band(bit.rshift(byte, 4), 0xf) -- 104
		end, -- 102

		getFilterApply = function(self) -- 106
			local byte = self.registers[24] -- 107
			return { -- 109
				bit.band(byte, 0x1) ~= 0, -- 109
				bit.band(byte, 0x2) ~= 0, -- 110
				bit.band(byte, 0x4) ~= 0 -- 111
			} -- 108
		end, -- 106

		getFilterPass = function(self) -- 114
			local byte = self.registers[25] -- 115
			return { -- 117
				lp = bit.band(byte, 0x10) ~= 0, -- 117
				bp = bit.band(byte, 0x20) ~= 0, -- 118
				hp = bit.band(byte, 0x40) ~= 0 -- 119
			} -- 116
		end, -- 114

		getChannel3Off = function(self) -- 122
			local byte = self.registers[25] -- 123
			return bit.band(byte, 0x80) == 0x80 -- 124
		end, -- 122

		updateEnvelopes = function(self) -- 126
			for ch = 1, 3 do -- 127
				local state = self._channel_state[ch] -- 128
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
			end -- 127
		end, -- 126

		processFilter = function(self, input, pass, resonance) -- 160
			local fs_low, fs_band -- 161
			do -- 161
				local _obj_0 = self._filter_state -- 161
				fs_low, fs_band = _obj_0.low, _obj_0.band -- 161
			end -- 161
			local lp, bp, hp = pass.lp, pass.bp, pass.hp -- 162
			local output = 0 -- 163

			local cutoff = self:getFilterCutoff() -- 165

			local f = cutoff / 2047 * 0.7 -- 167
			if f > 0.85 then -- 168
				f = 0.85 -- 169
			end -- 168

			local q = 1.0 - resonance / 15 -- 171
			if q < 0.05 then -- 172
				q = 0.05 -- 173
			end -- 172

			local high = input - fs_low - q * fs_band -- 175
			fs_band = fs_band + f * high -- 176
			fs_low = fs_low + f * fs_band -- 177

			if fs_band > 1 then -- 179
				fs_band = 1 -- 179
			elseif fs_band < -1 then -- 180
				fs_band = -1 -- 180
			end -- 179

			if fs_low > 1 then -- 182
				fs_low = 1 -- 182
			elseif fs_low < -1 then -- 183
				fs_low = -1 -- 183
			end -- 182

			if lp then -- 185
				output = output + fs_low -- 185
			end -- 185
			if bp then -- 186
				output = output + fs_band -- 186
			end -- 186
			if hp then -- 187
				output = output + high -- 187
			end -- 187

			return output * 0.8 + input * 0.2 -- 189
		end, -- 160

		stepOscillators = function(self) -- 191
			local clock = self:getClock() -- 192
			local dt_clock = clock / SAMPLE_RATE -- 193

			for ch = 1, 3 do -- 195
				local state = self._channel_state[ch] -- 196
				local test = self:getControl(ch).test -- 197

				state.prev_acc = state.acc -- 199
				if test then -- 200
					state.noise_reg = 0xfffff -- 201
					state.acc = 0 -- 202
				else -- 204
					local freq = self:getFrequencyWord(ch) -- 204
					state.acc = (state.acc + freq * dt_clock) % 16777216 -- 205
				end -- 200
			end -- 195

			for ch = 1, 3 do -- 207
				local sync = self:getControl(ch).sync -- 208
				if sync then -- 209
					local mod_i -- 210
					if ch == 1 then -- 210
						mod_i = 3 -- 210
					else -- 210
						mod_i = ch - 1 -- 210
					end -- 210
					if self._channel_state[mod_i].acc < self._channel_state[mod_i].prev_acc then -- 211
						self._channel_state[mod_i].acc = 0 -- 212
					end -- 211
				end -- 209
			end -- 207
		end, -- 191

		getNoiseSample = function(self, ch) -- 214
			local state = self._channel_state[ch] -- 215
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
		end, -- 214

		getSample = function(self, ch) -- 242
			local state = self._channel_state[ch] -- 243
			local mod_i -- 244
			if ch == 1 then -- 244
				mod_i = 3 -- 244
			else -- 244
				mod_i = ch - 1 -- 244
			end -- 244
			local ring, test, tri, saw, pulse, noise -- 245
			do -- 245
				local _obj_0 = self:getControl(ch) -- 245
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
				local mod_acc = self._channel_state[mod_i].acc -- 255

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
				local pw = self:getPulseWidth(ch) -- 278
				local acc12 = bit.band(bit.rshift(acc_i, 12), 0xfff) -- 279
				local v = (acc12 < pw) and 0xff or 0x00 -- 280
				sample_raw = bit.band(sample_raw, v) -- 281
				any_wave = true -- 282
			end -- 277
			if noise then -- 283
				local v = self:getNoiseSample(ch) -- 284
				sample_raw = bit.band(sample_raw, v) -- 285
				any_wave = true -- 286
			end -- 283

			if not any_wave then -- 288
				return 0 -- 288
			end -- 288

			local sample = sample_raw / 127.5 - 1 -- 290
			return sample * state.env_level / _anon_func_0() -- 291
		end, -- 242

		renderSample = function(self) -- 293
			local mixed_sample = 0 -- 294
			local ch_samples = { } -- 295

			local filter_apply = self:getFilterApply() -- 297
			local filter_pass = self:getFilterPass() -- 298
			local resonance = self:getFilterResonance() -- 299
			local volume = self:getVolume() / 15 -- 300

			for ch = 1, 3 do -- 302
				local sample = self:getSample(ch) -- 303
				if filter_apply[ch] then -- 304
					sample = self:processFilter(sample, filter_pass, resonance) -- 304
				end -- 304
				ch_samples[ch] = sample -- 305
				mixed_sample = mixed_sample + sample -- 306
			end -- 302

			return mixed_sample * volume, ch_samples -- 308
		end, -- 293

		step = function(self) -- 310
			self:updateEnvelopes() -- 311
			return self:stepOscillators() -- 312
		end -- 310
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
						rawset(self, k, v) -- 47
						return -- 48
					end -- 44
				end -- 43
			}) -- 37

			do -- 51
				local _accum_0 = { } -- 51
				local _len_0 = 1 -- 51
				for i = 1, 3 do -- 51
					_accum_0[_len_0] = { -- 52
						acc = 0.0, -- 52
						prev_acc = 0.0, -- 52
						env_level = 0, -- 52
						env_state = ENV_STATE.IDLE, -- 52
						noise_reg = 0xfffff, -- 52
						last_bit19 = 0 -- 52
					} -- 52
					_len_0 = _len_0 + 1 -- 52
				end -- 51
				self._channel_state = _accum_0 -- 51
			end -- 51
			self._filter_state = { -- 53
				low = 0, -- 53
				band = 0 -- 53
			} -- 53
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
end -- 26
_module_0["Sid"] = Sid -- 26

local SidMixer -- 314
local _class_0 -- 314
local _base_0 = { -- 314

	addSid = function(self, sid, pan) -- 323
		if pan == nil then -- 323
			pan = 0 -- 323
		end -- 323
		--if not getmetatable(sid) or getmetatable(sid).__index != Sid then return
		self._sids[sid] = { -- 325
			pan = pan -- 325
		} -- 325
	end, -- 323

	removeSid = function(self, sid) -- 327
		self._sids[sid] = nil -- 328
	end, -- 327

	renderSample = function(self) -- 330
		local left = 0 -- 331
		local right = 0 -- 331
		for sid, prop in pairs(self._sids) do -- 332
			local sample = sid:renderSample() -- 333

			local pan = prop.pan -- 335

			left = left + (sample * math.sqrt((1 - pan) / 2)) -- 337
			right = right + (sample * math.sqrt((1 + pan) / 2)) -- 338

			sid:step() -- 340
		end -- 332

		left = math.max(-1, math.min(1, left)) -- 342
		right = math.max(-1, math.min(1, right)) -- 343

		return left, right -- 345
	end, -- 330

	renderBuffer = function(self) -- 347
		for i = 0, self.buffer_size - 1 do -- 348
			local left, right = self:renderSample() -- 349

			self._buffer:setSample(i, 1, left) -- 351
			self._buffer:setSample(i, 2, right) -- 352
		end -- 348

		return self._buffer -- 354
	end, -- 347

	play = function(self) -- 356
		while self.source:getFreeBufferCount() > 0 do -- 357
			self.source:queue(self:renderBuffer()) -- 358
		end -- 357
		return self.source:play() -- 359
	end -- 356
} -- 314
if _base_0.__index == nil then -- 314
	_base_0.__index = _base_0 -- 314
end -- 314
_class_0 = setmetatable({ -- 314
	__init = function(self, buffer_size, buffer_count) -- 315
		if buffer_size == nil then -- 315
			buffer_size = 1024 -- 315
		end -- 315
		if buffer_count == nil then -- 315
			buffer_count = 8 -- 315
		end -- 315
		self.buffer_size = buffer_size -- 316
		self.buffer_count = buffer_count -- 317
		self.source = love.audio.newQueueableSource(SAMPLE_RATE, 16, 2, buffer_count) -- 318

		self._sids = { } -- 320
		self._buffer = love.sound.newSoundData(self.buffer_size, SAMPLE_RATE, 16, 2) -- 321
	end, -- 315
	__base = _base_0, -- 314
	__name = "SidMixer" -- 314
}, { -- 314
	__index = _base_0, -- 314
	__call = function(cls, ...) -- 314
		local _self_0 = setmetatable({ }, _base_0) -- 314
		cls.__init(_self_0, ...) -- 314
		return _self_0 -- 314
	end -- 314
}) -- 314
_base_0.__class = _class_0 -- 314
SidMixer = _class_0 -- 314
_module_0["SidMixer"] = SidMixer -- 314
return _module_0 -- 1
