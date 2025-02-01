;;NewVoice
(d-NewStructuredStaff 'voice)
(d-InheritStaffProperties)
(d-MoveToStaffUp)
(d-GoToBeginning)
(while (d-NextObject)
	(if (Keysignature?)
		(begin
			(d-PushPosition)
			(d-SetMark)(d-Copy)
			(d-MoveToStaffDown)
			(d-Paste)
			(d-PopPosition))))
