-- [yue]: lovesid.yue
local _module_0 = nil
local bit = require("bit")
local CLOCK = {
	PAL = 985248,
	NTSC = 1022727
}
local SAMPLE_RATE = 44100
local SAMPLE_DT = 1 / SAMPLE_RATE
local ADSR_LOOKUP = {
	ATTACK = {
		0.002,
		0.008,
		0.016,
		0.024,
		0.038,
		0.056,
		0.068,
		0.080,
		0.100,
		0.250,
		0.500,
		0.800,
		1.000,
		3.000,
		5.000,
		8.000
	},
	DECAY = {
		0.006,
		0.024,
		0.048,
		0.072,
		0.114,
		0.168,
		0.204,
		0.240,
		0.300,
		0.750,
		1.500,
		2.400,
		3.000,
		9.000,
		15.00,
		24.00
	},
	RELEASE = {
		0.006,
		0.024,
		0.048,
		0.072,
		0.114,
		0.168,
		0.204,
		0.240,
		0.300,
		0.750,
		1.500,
		2.400,
		3.000,
		9.000,
		15.00,
		24.00
	}
}
local ENV_STATE = {
	IDLE = 1,
	ATTACK = 2,
	DECAY = 3,
	SUSTAIN = 4,
	RELEASE = 5
}
local channels
do
	local _accum_0 = { }
	local _len_0 = 1
	for i = 1, 3 do
		_accum_0[_len_0] = {
			acc = 0.0,
			prev_acc = 0.0,
			env_level = 0,
			env_state = ENV_STATE.IDLE,
			noise_reg = 0xfffff,
			last_bit19 = 0
		}
		_len_0 = _len_0 + 1
	end
	channels = _accum_0
end
local filter = {
	low = 0,
	band = 0
}
local buffer_size, buffer_count
local _registers = setmetatable({ }, {
	__index = function(self, k)
		local _exp_0 = rawget(self, k)
		if _exp_0 ~= nil then
			return _exp_0
		else
			return 0
		end
	end
})
local lovesid = setmetatable({
	source = love.audio.newQueueableSource(SAMPLE_RATE, 16, 1, buffer_count),
	is_ntsc = false
}, {
	__newindex = function(self, k, v)
		if type(k) == "number" and 1 <= k and k <= 25 then
			_registers[k] = bit.band(v, 0xff)
		else
			rawset(self, k, v)
			return
		end
	end,
	__index = function(self, k)
		if type(k) == "number" then
			return _registers[k]
		else
			return rawget(self, k)
		end
	end
})
lovesid.configure = function(self, o)
	if o == nil then
		o = { }
	end
	do
		local _exp_0 = o.buffer_size
		if _exp_0 ~= nil then
			buffer_size = _exp_0
		else
			buffer_size = 1024
		end
	end
	do
		local _exp_0 = o.buffer_count
		if _exp_0 ~= nil then
			buffer_count = _exp_0
		else
			buffer_count = 8
		end
	end
	do
		local _obj_0 = self.source
		if _obj_0 ~= nil then
			_obj_0:stop()
		end
	end
	self.source = love.audio.newQueueableSource(SAMPLE_RATE, 16, 1, buffer_count)
end
lovesid:configure()
local getClock
getClock = function()
	return lovesid.is_ntsc and CLOCK.NTSC or CLOCK.PAL
end
local getChannelOffset
getChannelOffset = function(ch)
	return (ch - 1) * 7 + 1
end
local getFrequency
getFrequency = function(ch)
	local offset = getChannelOffset(ch)
	local lo, hi = _registers[offset], _registers[offset + 1]
	return bit.bor(bit.lshift(hi, 8), lo)
end
local wordToHz
wordToHz = function(word)
	return word * getClock() / 16777216
end
local getPulseWidth
getPulseWidth = function(ch)
	local offset = getChannelOffset(ch) + 2
	local lo, hi = _registers[offset], bit.band(_registers[offset + 1], 0xf)
	local _exp_0 = bit.bor(bit.lshift(hi, 8), lo)
	if _exp_0 ~= nil then
		return _exp_0
	else
		return 0
	end
end
local getControl
getControl = function(ch)
	local offset = getChannelOffset(ch) + 4
	local byte = _registers[offset]
	return {
		gate = bit.band(byte, 0x01) ~= 0,
		sync = bit.band(byte, 0x02) ~= 0,
		ring = bit.band(byte, 0x04) ~= 0,
		test = bit.band(byte, 0x08) ~= 0,
		tri = bit.band(byte, 0x10) ~= 0,
		saw = bit.band(byte, 0x20) ~= 0,
		pulse = bit.band(byte, 0x40) ~= 0,
		noise = bit.band(byte, 0x80) ~= 0
	}
end
local getADSR
getADSR = function(ch)
	local offset = getChannelOffset(ch) + 5
	local AD, SR = _registers[offset], _registers[offset + 1]
	return {
		a = bit.band(bit.rshift(AD, 4), 0xf),
		d = bit.band(AD, 0xf),
		s = bit.band(bit.rshift(SR, 4), 0xf),
		r = bit.band(SR, 0xf)
	}
end
local getVolume
getVolume = function()
	local byte = _registers[25]
	return bit.band(byte, 0xf)
end
local getFilterCutoff
getFilterCutoff = function()
	local lo, hi = bit.band(_registers[22], 0x7), _registers[23]
	return bit.bor(lo, bit.lshift(hi, 3))
end
local getFilterResonance
getFilterResonance = function()
	local byte = _registers[24]
	return bit.band(bit.rshift(byte, 4), 0xf)
end
local getFilterApply
getFilterApply = function()
	local byte = _registers[24]
	return {
		bit.band(byte, 0x1) ~= 0,
		bit.band(byte, 0x2) ~= 0,
		bit.band(byte, 0x4) ~= 0
	}
end
local getFilterPass
getFilterPass = function()
	local byte = _registers[25]
	return {
		low_pass = bit.band(byte, 0x10) ~= 0,
		band_pass = bit.band(byte, 0x20) ~= 0,
		high_pass = bit.band(byte, 0x40) ~= 0
	}
end
local getChannel3Off
getChannel3Off = function()
	local byte = _registers[25]
	return bit.band(byte, 0x80) == 0x80
end
local updateEnvelope
updateEnvelope = function(ch)
	local state = channels[ch]
	local gate = getControl(ch).gate
	local a, d, s, r
	do
		local _obj_0 = getADSR(ch)
		a, d, s, r = _obj_0.a, _obj_0.d, _obj_0.s, _obj_0.r
	end
	local sustain_level = s * 17
	if gate then
		if state.env_state == ENV_STATE.IDLE or state.env_state == ENV_STATE.RELEASE then
			state.env_state = ENV_STATE.ATTACK
		end
	else
		state.env_state = ENV_STATE.RELEASE
	end
	if state.env_state == ENV_STATE.ATTACK then
		local duration = ADSR_LOOKUP.ATTACK[a + 1]
		state.env_level = state.env_level + 255 / duration * SAMPLE_DT
		if state.env_level >= 255 then
			state.env_level = 255
			state.env_state = ENV_STATE.DECAY
		end
	elseif state.env_state == ENV_STATE.DECAY then
		local duration = ADSR_LOOKUP.DECAY[d + 1]
		state.env_level = state.env_level - 255 / duration * SAMPLE_DT
		if state.env_level <= sustain_level then
			state.env_level = sustain_level
			state.env_state = ENV_STATE.SUSTAIN
		end
	elseif state.env_state == ENV_STATE.SUSTAIN then
		state.env_level = sustain_level
	elseif state.env_state == ENV_STATE.RELEASE then
		local duration = ADSR_LOOKUP.RELEASE[r + 1]
		state.env_level = state.env_level - 255 / duration * SAMPLE_DT
		if state.env_level <= 0 then
			state.env_level = 0
			state.env_state = ENV_STATE.IDLE
		end
	end
end
local processFilter
processFilter = function(input, lp, bp, hp, resonance)
	local output = 0
	local cutoff = getFilterCutoff()
	local f = cutoff / 2047 * 0.7
	if f > 0.85 then
		f = 0.85
	end
	local q = 1.0 - resonance / 15
	if q < 0.05 then
		q = 0.05
	end
	local high = input - filter.low - q * filter.band
	filter.band = filter.band + f * high
	filter.low = filter.low + f * filter.band
	if filter.band > 1 then
		filter.band = 1
	elseif filter.band < -1 then
		filter.band = -1
	end
	if filter.low > 1 then
		filter.low = 1
	elseif filter.low < -1 then
		filter.low = -1
	end
	if lp then
		output = output + filter.low
	end
	if bp then
		output = output + filter.band
	end
	if hp then
		output = output + high
	end
	return output * 0.8 + input * 0.2
end
local stepOscillators
stepOscillators = function()
	local clock = getClock()
	local dt_clock = clock / SAMPLE_RATE
	for i = 1, 3 do
		local state = channels[i]
		local test = getControl(i).test
		state.prev_acc = state.acc
		if test then
			state.noise_reg = 0xfffff
			state.acc = 0
		else
			local freq = getFrequency(i)
			state.acc = (state.acc + freq * dt_clock) % 16777216
		end
	end
	for i = 1, 3 do
		local sync = getControl(i).sync
		if sync then
			local mod_i
			if i == 1 then
				mod_i = 3
			else
				mod_i = i - 1
			end
			if channels[mod_i].acc < channels[mod_i].prev_acc then
				channels[mod_i].acc = 0
			end
		end
	end
end
local getNoiseSample
getNoiseSample = function(ch)
	local state = channels[ch]
	local acc_i = math.floor(state.acc)
	local current_bit19 = bit.band(bit.rshift(acc_i, 19), 1)
	if state.last_bit19 == 0 and current_bit19 == 1 then
		local reg = state.noise_reg
		local bit22 = bit.band(bit.rshift(reg, 22), 1)
		local bit17 = bit.band(bit.rshift(reg, 17), 1)
		local feedback = bit.bxor(bit22, bit17)
		reg = bit.band(bit.lshift(reg, 1), 0x7fffff)
		reg = bit.bor(reg, feedback)
		state.noise_reg = reg
	end
	state.last_bit19 = current_bit19
	local r = state.noise_reg
	local out = 0
	out = bit.bor(out, bit.lshift(bit.band(bit.rshift(r, 22), 1), 7))
	out = bit.bor(out, bit.lshift(bit.band(bit.rshift(r, 20), 1), 6))
	out = bit.bor(out, bit.lshift(bit.band(bit.rshift(r, 16), 1), 5))
	out = bit.bor(out, bit.lshift(bit.band(bit.rshift(r, 13), 1), 4))
	out = bit.bor(out, bit.lshift(bit.band(bit.rshift(r, 11), 1), 3))
	out = bit.bor(out, bit.lshift(bit.band(bit.rshift(r, 7), 1), 2))
	out = bit.bor(out, bit.lshift(bit.band(bit.rshift(r, 4), 1), 1))
	return bit.bor(out, bit.band(bit.rshift(r, 2), 1))
end
local _anon_func_0 = function()
	local _exp_0 = 0xff
	if _exp_0 ~= nil then
		return _exp_0
	else
		return 0
	end
end
local getSample
getSample = function(ch)
	local state = channels[ch]
	local mod_i
	if ch == 1 then
		mod_i = 3
	else
		mod_i = ch - 1
	end
	local ring, test, tri, saw, pulse, noise
	do
		local _obj_0 = getControl(ch)
		ring, test, tri, saw, pulse, noise = _obj_0.ring, _obj_0.test, _obj_0.tri, _obj_0.saw, _obj_0.pulse, _obj_0.noise
	end
	if test then
		return 0
	end
	local sample_raw = 0xff
	local any_wave = false
	local acc_i = math.floor(state.acc)
	if tri then
		local raw_tri_acc = acc_i
		local mod_acc = channels[mod_i].acc
		if ring then
			local car_msb = bit.band(bit.rshift(acc_i, 23), 1)
			local mod_msb = bit.band(bit.rshift(mod_acc, 23), 1)
			local ring_msb = bit.bxor(car_msb, mod_msb)
			raw_tri_acc = bit.bor(bit.band(acc_i, 0x7fffff), bit.lshift(ring_msb, 23))
		end
		local msb = bit.band(bit.rshift(raw_tri_acc, 23), 1)
		local v = bit.band(bit.rshift(raw_tri_acc, 16), 0x7f)
		if msb == 1 then
			v = 0x7f - v
		end
		sample_raw = bit.band(sample_raw, v * 2)
		any_wave = true
	end
	if saw then
		local v = bit.band(bit.rshift(acc_i, 16), 0xff)
		sample_raw = bit.band(sample_raw, v)
		any_wave = true
	end
	if pulse then
		local pw = getPulseWidth(ch)
		local acc12 = bit.band(bit.rshift(acc_i, 12), 0xfff)
		local v = (acc12 < pw) and 0xff or 0x00
		sample_raw = bit.band(sample_raw, v)
		any_wave = true
	end
	if noise then
		local v = getNoiseSample(ch)
		sample_raw = bit.band(sample_raw, v)
		any_wave = true
	end
	if not any_wave then
		return 0
	end
	local sample = sample_raw / 127.5 - 1
	return sample * state.env_level / _anon_func_0()
end
lovesid.update = function(self)
	self.source:play()
	while self.source:getFreeBufferCount() > 0 do
		local sound_data = love.sound.newSoundData(buffer_size, SAMPLE_RATE, 16, 1)
		local filter_apply = getFilterApply()
		local filter_pass = getFilterPass()
		local res = getFilterResonance()
		local main_vol = getVolume() / 15
		for i = 0, buffer_size - 1 do
			for ch = 1, 3 do
				updateEnvelope(ch)
			end
			stepOscillators()
			local through_filter = 0
			local unfiltered = 0
			for ch = 1, 3 do
				local sample = getSample(ch) / 3
				if filter_apply[i] then
					through_filter = through_filter + sample
				else
					unfiltered = unfiltered + sample
				end
			end
			local output = unfiltered + processFilter(through_filter, filter_pass.low_pass, filter_pass.band_pass, filter_pass.high_pass, res)
			output = output * main_vol
			sound_data:setSample(i, math.max(-1, math.min(1, output)))
		end
		self.source:queue(sound_data)
	end
end
_module_0 = lovesid
return _module_0
