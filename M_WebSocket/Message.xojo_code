#tag Class
Private Class Message
	#tag Method, Flags = &h0
		Sub Constructor()
		  
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub Constructor(frame As M_WebSocket.Frame)
		  Constructor
		  Operator_Add frame
		  
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub Operator_Add(frame As M_WebSocket.Frame)
		  if self.Type = Types.Unknown then
		    mType = frame.Type
		    
		  elseif frame.Type <> self.Type then
		    raise new WebSocketException( "Frame type must match message type" )
		    
		  end if
		  
		  self.Content = self.Content + frame.Content
		  
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Function Type() As Message.Types
		  return mType
		End Function
	#tag EndMethod


	#tag Property, Flags = &h0
		Content As String
	#tag EndProperty

	#tag Property, Flags = &h0
		mType As Types = Types.Unknown
	#tag EndProperty


	#tag Enum, Name = Types, Type = Integer, Flags = &h0
		Unknown = -1
		  Continuation = 0
		  Text = 1
		  Binary = 2
		  ConnectionClose = 8
		  Ping = 9
		Pong = 10
	#tag EndEnum


	#tag ViewBehavior
		#tag ViewProperty
			Name="Content"
			Group="Behavior"
			Type="String"
		#tag EndViewProperty
		#tag ViewProperty
			Name="Index"
			Visible=true
			Group="ID"
			InitialValue="-2147483648"
			Type="Integer"
		#tag EndViewProperty
		#tag ViewProperty
			Name="Left"
			Visible=true
			Group="Position"
			InitialValue="0"
			Type="Integer"
		#tag EndViewProperty
		#tag ViewProperty
			Name="mType"
			Group="Behavior"
			InitialValue="Types.Unknown"
			Type="Types"
			EditorType="Enum"
			#tag EnumValues
				"-1 - Unknown"
				"0 - Continuation"
				"1 - Text"
				"2 - Binary"
				"8 - ConnectionClose"
				"9 - Ping"
				"10 - Pong"
			#tag EndEnumValues
		#tag EndViewProperty
		#tag ViewProperty
			Name="Name"
			Visible=true
			Group="ID"
			Type="String"
		#tag EndViewProperty
		#tag ViewProperty
			Name="Super"
			Visible=true
			Group="ID"
			Type="String"
		#tag EndViewProperty
		#tag ViewProperty
			Name="Top"
			Visible=true
			Group="Position"
			InitialValue="0"
			Type="Integer"
		#tag EndViewProperty
	#tag EndViewBehavior
End Class
#tag EndClass
