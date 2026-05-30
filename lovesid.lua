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

local DEFAULT_SID_CONFIG = { -- 25
	pan = 0 -- 25
} -- 25

-- define classes
local _anon_func_0 = function() -- 294
	local _exp_0 = 0xff -- 294
	if _exp_0 ~= nil then -- 294
		return _exp_0 -- 294
	else -- 294
		return 0 -- 294
	end -- 294
end -- 294
local Sid -- 28
do -- 28
	local _class_0 -- 28
	local _base_0 = { -- 28

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
				lp = bit.band(byte, 0x10) ~= 0, -- 118
				bp = bit.band(byte, 0x20) ~= 0, -- 119
				hp = bit.band(byte, 0x40) ~= 0 -- 120
			} -- 117
		end, -- 115

		getChannel3Off = function(self) -- 123
			local byte = self.registers[25] -- 124
			return bit.band(byte, 0x80) == 0x80 -- 125
		end, -- 123

		updateEnvelopes = function(self) -- 127
			for ch = 1, 3 do -- 128
				local state = self._channel_state[ch] -- 129
				local gate = self:getControl(ch).gate -- 130
				local a, d, s, r -- 131
				do -- 131
					local _obj_0 = self:getADSR(ch) -- 131
					a, d, s, r = _obj_0.a, _obj_0.d, _obj_0.s, _obj_0.r -- 131
				end -- 131
				local sustain_level = s * 17 -- 132

				if gate and not state.prev_gate then -- 134
					state.env_state = ENV_STATE.ATTACK -- 135
				elseif not gate and state.prev_gate then -- 136
					state.env_state = ENV_STATE.RELEASE -- 137
				end -- 134

				local _exp_0 = state.env_state -- 139
				if ENV_STATE.ATTACK == _exp_0 then -- 140
					local duration = ADSR_LOOKUP.ATTACK[a + 1] -- 141
					state.env_level = state.env_level + ((255 / duration) * SAMPLE_DT) -- 142
					if state.env_level >= 255 then -- 143
						state.env_level = 255 -- 144
						state.env_state = ENV_STATE.DECAY -- 145
					end -- 143
				elseif ENV_STATE.DECAY == _exp_0 then -- 146
					local duration = ADSR_LOOKUP.DECAY[d + 1] -- 147
					state.env_level = state.env_level - ((255 / duration) * SAMPLE_DT) -- 148
					if state.env_level <= sustain_level then -- 149
						state.env_level = sustain_level -- 150
						state.env_state = ENV_STATE.SUSTAIN -- 151
					end -- 149
				elseif ENV_STATE.SUSTAIN == _exp_0 then -- 152
					state.env_level = sustain_level -- 153
				elseif ENV_STATE.RELEASE == _exp_0 then -- 154
					local duration = ADSR_LOOKUP.RELEASE[r + 1] -- 155
					state.env_level = state.env_level - ((255 / duration) * SAMPLE_DT) -- 156
					if state.env_level <= 0 then -- 157
						state.env_level = 0 -- 158
						state.env_state = ENV_STATE.IDLE -- 159
					end -- 157
				elseif ENV_STATE.IDLE == _exp_0 then -- 160
					state.env_level = 0 -- 161
				end -- 139
			end -- 128
		end, -- 127

		processFilter = function(self, input, pass, resonance) -- 163
			local fs_low, fs_band -- 164
			do -- 164
				local _obj_0 = self._filter_state -- 164
				fs_low, fs_band = _obj_0.low, _obj_0.band -- 164
			end -- 164
			local lp, bp, hp = pass.lp, pass.bp, pass.hp -- 165
			local output = 0 -- 166

			local cutoff = self:getFilterCutoff() -- 168

			local f = cutoff / 2047 * 0.7 -- 170
			if f > 0.85 then -- 171
				f = 0.85 -- 172
			end -- 171

			local q = 1.0 - resonance / 15 -- 174
			if q < 0.05 then -- 175
				q = 0.05 -- 176
			end -- 175

			local high = input - fs_low - q * fs_band -- 178
			fs_band = fs_band + f * high -- 179
			fs_low = fs_low + f * fs_band -- 180

			if fs_band > 1 then -- 182
				fs_band = 1 -- 182
			elseif fs_band < -1 then -- 183
				fs_band = -1 -- 183
			end -- 182

			if fs_low > 1 then -- 185
				fs_low = 1 -- 185
			elseif fs_low < -1 then -- 186
				fs_low = -1 -- 186
			end -- 185

			if lp then -- 188
				output = output + fs_low -- 188
			end -- 188
			if bp then -- 189
				output = output + fs_band -- 189
			end -- 189
			if hp then -- 190
				output = output + high -- 190
			end -- 190

			return output -- 192
		end, -- 163

		stepOscillators = function(self) -- 194
			local clock = self:getClock() -- 195
			local dt_clock = clock / SAMPLE_RATE -- 196

			for ch = 1, 3 do -- 198
				local state = self._channel_state[ch] -- 199
				local test = self:getControl(ch).test -- 200

				state.prev_acc = state.acc -- 202
				if test then -- 203
					state.noise_reg = 0xfffff -- 204
					state.acc = 0 -- 205
				else -- 207
					local freq = self:getFrequencyWord(ch) -- 207
					state.acc = (state.acc + freq * dt_clock) % 16777216 -- 208
				end -- 203
			end -- 198

			for ch = 1, 3 do -- 210
				local sync = self:getControl(ch).sync -- 211
				if sync then -- 212
					local mod_i -- 213
					if ch == 1 then -- 213
						mod_i = 3 -- 213
					else -- 213
						mod_i = ch - 1 -- 213
					end -- 213
					if self._channel_state[mod_i].acc < self._channel_state[mod_i].prev_acc then -- 214
						self._channel_state[mod_i].acc = 0 -- 215
					end -- 214
				end -- 212
			end -- 210
		end, -- 194

		getNoiseSample = function(self, ch) -- 217
			local state = self._channel_state[ch] -- 218
			local acc_i = math.floor(state.acc) -- 219
			local current_bit19 = bit.band(bit.rshift(acc_i, 19), 1) -- 220

			if state.last_bit19 == 0 and current_bit19 == 1 then -- 222
				local reg = state.noise_reg -- 223
				local bit22 = bit.band(bit.rshift(reg, 22), 1) -- 224
				local bit17 = bit.band(bit.rshift(reg, 17), 1) -- 225
				local feedback = bit.bxor(bit22, bit17) -- 226

				reg = bit.band(bit.lshift(reg, 1), 0x7fffff) -- 228
				reg = bit.bor(reg, feedback) -- 229

				state.noise_reg = reg -- 231
			end -- 222
			state.last_bit19 = current_bit19 -- 232

			local r = state.noise_reg -- 234
			local out = 0 -- 235
			out = bit.bor(out, bit.lshift(bit.band(bit.rshift(r, 22), 1), 7)) -- 236
			out = bit.bor(out, bit.lshift(bit.band(bit.rshift(r, 20), 1), 6)) -- 237
			out = bit.bor(out, bit.lshift(bit.band(bit.rshift(r, 16), 1), 5)) -- 238
			out = bit.bor(out, bit.lshift(bit.band(bit.rshift(r, 13), 1), 4)) -- 239
			out = bit.bor(out, bit.lshift(bit.band(bit.rshift(r, 11), 1), 3)) -- 240
			out = bit.bor(out, bit.lshift(bit.band(bit.rshift(r, 7), 1), 2)) -- 241
			out = bit.bor(out, bit.lshift(bit.band(bit.rshift(r, 4), 1), 1)) -- 242
			return bit.bor(out, bit.band(bit.rshift(r, 2), 1)) -- 243
		end, -- 217

		getSample = function(self, ch) -- 245
			local state = self._channel_state[ch] -- 246
			local mod_i -- 247
			if ch == 1 then -- 247
				mod_i = 3 -- 247
			else -- 247
				mod_i = ch - 1 -- 247
			end -- 247
			local ring, test, tri, saw, pulse, noise -- 248
			do -- 248
				local _obj_0 = self:getControl(ch) -- 248
				ring, test, tri, saw, pulse, noise = _obj_0.ring, _obj_0.test, _obj_0.tri, _obj_0.saw, _obj_0.pulse, _obj_0.noise -- 248
			end -- 248

			if test then -- 250
				return 0 -- 250
			end -- 250

			local sample_raw = 0xff -- 252
			local any_wave = false -- 253
			local acc_i = math.floor(state.acc) -- 254

			if tri then -- 256
				local raw_tri_acc = acc_i -- 257
				local mod_acc = self._channel_state[mod_i].acc -- 258

				if ring then -- 260
					local car_msb = bit.band(bit.rshift(acc_i, 23), 1) -- 261
					local mod_msb = bit.band(bit.rshift(mod_acc, 23), 1) -- 262
					local ring_msb = bit.bxor(car_msb, mod_msb) -- 263

					raw_tri_acc = bit.bor(bit.band(acc_i, 0x7fffff), bit.lshift(ring_msb, 23)) -- 265
				end -- 260

				local msb = bit.band(bit.rshift(raw_tri_acc, 23), 1) -- 270
				local v = bit.band(bit.rshift(raw_tri_acc, 16), 0x7f) -- 271

				if msb == 1 then -- 273
					v = 0x7f - v -- 273
				end -- 273
				sample_raw = bit.band(sample_raw, v * 2) -- 274
				any_wave = true -- 275
			end -- 256
			if saw then -- 276
				local v = bit.band(bit.rshift(acc_i, 16), 0xff) -- 277
				sample_raw = bit.band(sample_raw, v) -- 278
				any_wave = true -- 279
			end -- 276
			if pulse then -- 280
				local pw = self:getPulseWidth(ch) -- 281
				local acc12 = bit.band(bit.rshift(acc_i, 12), 0xfff) -- 282
				local v = (acc12 < pw) and 0xff or 0x00 -- 283
				sample_raw = bit.band(sample_raw, v) -- 284
				any_wave = true -- 285
			end -- 280
			if noise then -- 286
				local v = self:getNoiseSample(ch) -- 287
				sample_raw = bit.band(sample_raw, v) -- 288
				any_wave = true -- 289
			end -- 286

			if not any_wave then -- 291
				return 0 -- 291
			end -- 291

			local sample = sample_raw / 127.5 - 1 -- 293
			return sample * state.env_level / _anon_func_0() -- 294
		end, -- 245

		renderSample = function(self) -- 296
			local mixed_sample = 0 -- 297
			local ch_samples = { } -- 298

			local filter_apply = self:getFilterApply() -- 300
			local filter_pass = self:getFilterPass() -- 301
			local resonance = self:getFilterResonance() -- 302
			local volume = self:getVolume() / 15 -- 303

			for ch = 1, 3 do -- 305
				local sample = self:getSample(ch) -- 306
				if filter_apply[ch] then -- 307
					sample = self:processFilter(sample, filter_pass, resonance) -- 307
				end -- 307
				ch_samples[ch] = sample -- 308
				mixed_sample = mixed_sample + sample -- 309
			end -- 305

			return mixed_sample * volume, ch_samples -- 311
		end, -- 296

		step = function(self) -- 313
			self:updateEnvelopes() -- 314
			return self:stepOscillators() -- 315
		end -- 313
	} -- 28
	if _base_0.__index == nil then -- 28
		_base_0.__index = _base_0 -- 28
	end -- 28
	_class_0 = setmetatable({ -- 28
		__init = function(self, is_ntsc) -- 29
			if is_ntsc == nil then -- 29
				is_ntsc = false -- 29
			end -- 29
			self.is_ntsc = is_ntsc -- 30

			self.registers = setmetatable({ }, { -- 33
				__index = function() -- 33
					return 0 -- 33
				end, -- 33
				__newindex = function(self, k, v) -- 34
					if 1 <= k and k <= 25 then -- 35
						rawset(self, k, bit.band(v, 0xff)) -- 35
					end -- 35
					return -- 36
				end -- 34
			}) -- 32
			setmetatable(self, { -- 39
				__index = function(self, k) -- 39
					if type(k) == "number" then -- 40
						return self.registers[k] -- 41
					else -- 43
						return Sid[k] -- 43
					end -- 40
				end, -- 39
				__newindex = function(self, k, v) -- 44
					if type(k) == "number" then -- 45
						self.registers[k] = v -- 46
					else -- 48
						rawset(self, k, v) -- 48
						return -- 49
					end -- 45
				end -- 44
			}) -- 38

			do -- 52
				local _accum_0 = { } -- 52
				local _len_0 = 1 -- 52
				for i = 1, 3 do -- 52
					_accum_0[_len_0] = { -- 53
						acc = 0.0, -- 53
						prev_acc = 0.0, -- 53
						env_level = 0, -- 53
						env_state = ENV_STATE.IDLE, -- 53
						noise_reg = 0xfffff, -- 53
						last_bit19 = 0, -- 53
						prev_gate = false -- 53
					} -- 53
					_len_0 = _len_0 + 1 -- 53
				end -- 52
				self._channel_state = _accum_0 -- 52
			end -- 52
			self._filter_state = { -- 54
				low = 0, -- 54
				band = 0 -- 54
			} -- 54
		end, -- 29
		__base = _base_0, -- 28
		__name = "Sid" -- 28
	}, { -- 28
		__index = _base_0, -- 28
		__call = function(cls, ...) -- 28
			local _self_0 = setmetatable({ }, _base_0) -- 28
			cls.__init(_self_0, ...) -- 28
			return _self_0 -- 28
		end -- 28
	}) -- 28
	_base_0.__class = _class_0 -- 28
	Sid = _class_0 -- 28
end -- 28
_module_0["Sid"] = Sid -- 28

local SidMixer -- 317
local _class_0 -- 317
local _base_0 = { -- 317

	addSid = function(self, sid, config) -- 326
		if config == nil then -- 326
			config = DEFAULT_SID_CONFIG -- 326
		end -- 326
		self._sids[sid] = config -- 327
	end, -- 326

	removeSid = function(self, sid) -- 329
		self._sids[sid] = nil -- 330
	end, -- 329

	configureSid = function(self, sid, config) -- 332
		if (self._sids[sid] ~= nil) then -- 333
			for k, v in pairs(config) do -- 334
				self._sids[sid][k] = v -- 334
			end -- 334
		end -- 333
	end, -- 332

	reset = function(self) -- 336
		self._sids = { } -- 337
	end, -- 336

	renderSample = function(self) -- 339
		local left = 0 -- 340
		local right = 0 -- 340
		for sid, config in pairs(self._sids) do -- 341
			local sample = sid:renderSample() -- 342

			local pan = config.pan -- 344

			left = left + (sample * math.sqrt((1 - pan) / 2)) -- 346
			right = right + (sample * math.sqrt((1 + pan) / 2)) -- 347

			sid:step() -- 349
		end -- 341

		left = math.max(-1, math.min(1, left)) -- 351
		right = math.max(-1, math.min(1, right)) -- 352

		return left, right -- 354
	end, -- 339

	renderBuffer = function(self) -- 356
		for i = 0, self.buffer_size - 1 do -- 357
			local left, right = self:renderSample() -- 358

			self._buffer:setSample(i, 1, left) -- 360
			self._buffer:setSample(i, 2, right) -- 361
		end -- 357

		return self._buffer -- 363
	end, -- 356

	play = function(self) -- 365
		while self.source:getFreeBufferCount() > 0 do -- 366
			self.source:queue(self:renderBuffer()) -- 367
		end -- 366
		return self.source:play() -- 368
	end -- 365
} -- 317
if _base_0.__index == nil then -- 317
	_base_0.__index = _base_0 -- 317
end -- 317
_class_0 = setmetatable({ -- 317
	__init = function(self, buffer_size, buffer_count) -- 318
		if buffer_size == nil then -- 318
			buffer_size = 1024 -- 318
		end -- 318
		if buffer_count == nil then -- 318
			buffer_count = 8 -- 318
		end -- 318
		self.buffer_size = buffer_size -- 319
		self.buffer_count = buffer_count -- 320
		self.source = love.audio.newQueueableSource(SAMPLE_RATE, 16, 2, buffer_count) -- 321

		self._sids = { } -- 323
		self._buffer = love.sound.newSoundData(self.buffer_size, SAMPLE_RATE, 16, 2) -- 324
	end, -- 318
	__base = _base_0, -- 317
	__name = "SidMixer" -- 317
}, { -- 317
	__index = _base_0, -- 317
	__call = function(cls, ...) -- 317
		local _self_0 = setmetatable({ }, _base_0) -- 317
		cls.__init(_self_0, ...) -- 317
		return _self_0 -- 317
	end -- 317
}) -- 317
_base_0.__class = _class_0 -- 317
SidMixer = _class_0 -- 317
_module_0["SidMixer"] = SidMixer -- 317
return _module_0 -- 1
