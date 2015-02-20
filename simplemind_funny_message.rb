module Simplemind
	module FunnyMessage
		# write everything in lower case
		def pages_count_message(c)
			if c < 0
				"are we in the antispace yet?"
			elsif c == 0
				"zero. everything has its time, like new posts."
			elsif c == 1
				"they say the first milion is always the hardest. but the first post is probably only testing one."
			elsif c <= 5
				"i'm only getting started."
			elsif c <= 10
				"i'm writing as fast as possible."
			elsif c < 20
				"a handful of posts."
			elsif c < 30
				"i've written more posts than ever."
			elsif c < 40
				"am I good or am I good?"
			elsif c < 60
				"lots of posts. it will be legion of posts some time."
			elsif c < 80
				"i really should find a girlfriend."
			elsif c < 100
				"I love you."
			elsif c < 120
				"holy shit!!!"
			elsif c < 150
				"throng of posts."
			elsif c < 160
				"and now let me code a new CMS."
			elsif c < 180
				"at this point I've probably written all I wanted. Time to learn to draw?"	
			elsif c < 200
				"thank you, my muses. Calliope, is that you?"
			elsif c < 230
				"thank you, my muses. and bugs. and things that irritate me."
			elsif c < 250
				"Nina Dobrev, will you marry me?"
			elsif c < 280
				"i always wanted a digital library..."
			elsif c <= 300
				"good, the fun begins now..."
			elsif c <= 320
				"program Simplemind, you said. it ought to be enough for everybody, you said."
			else
				"over 300!!!"
			end
		end
	end
end	
