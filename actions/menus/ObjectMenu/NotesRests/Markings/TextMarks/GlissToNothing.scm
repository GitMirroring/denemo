;;;GlissToNothing
(let ((tag "GlissToNothing")(params #f)(length #f)) 
    (if (equal? params "edit")
        (let ((choice (RadioBoxMenu (cons (_ "Recalculate") 'calc)
                        (cons (_ "Delete") 'delete)
                        (cons (_ "Advanced") 'advanced))))
          (case choice
                ((calc)
					(set! params #f)
                    (d-InfoDialog "Recalculated end point"))
                ((delete)
                    (d-DirectiveDelete-chord tag))
                ((advanced)
                    (d-DirectiveTextEdit-chord tag)))))
		(if (not params)
			(begin
				(d-DirectivePut-chord-display tag  "GlissToNothing" )
				(d-DirectivePut-chord-postfix tag  (string-append "*7/8\\glissando\\hideNotes " (d-GetCursorNoteWithOctave)(d-GetNoteDuration) "*1/8 \\unHideNotes"))
				(d-DirectivePut-chord-minpixels tag 20)))
        (d-SetSaved #f)
        (d-RefreshDisplay))
    