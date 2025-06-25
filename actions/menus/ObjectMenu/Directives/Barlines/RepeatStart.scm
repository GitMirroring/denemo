;;;RepeatStart
(if (d-CheckLilyVersion "2.20.0")
	(StandAloneSelfEditDirective (cons "RepeatStart" "\\bar \".|:-|\"") #t "RepeatStart")
	(StandAloneSelfEditDirective (cons "RepeatStart" "\\bar \".|:\"") #t "RepeatStart"))
