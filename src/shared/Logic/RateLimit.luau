--!strict
-- Limite de frequência (token bucket), puro. Cada pedido gasta 1 ficha; elas voltam a `rate` por segundo,
-- até `burst`. Pedido sem ficha é descartado no servidor (anti-spam de remotes).

local RateLimit = {}

export type Bucket = { Tokens: number, At: number, Rate: number, Burst: number }

function RateLimit.new(rate: number, burst: number, now: number): Bucket
	return { Tokens = burst, At = now, Rate = rate, Burst = burst }
end

function RateLimit.take(bucket: Bucket, now: number): boolean
	local elapsed = math.max(now - bucket.At, 0)
	bucket.At = math.max(now, bucket.At)
	bucket.Tokens = math.min(bucket.Burst, bucket.Tokens + elapsed * bucket.Rate)
	if bucket.Tokens >= 1 then
		bucket.Tokens -= 1
		return true
	end
	return false
end

return RateLimit
