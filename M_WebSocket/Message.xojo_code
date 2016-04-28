#tag Class
Private Class Message
	#tag Method, Flags = &h0
		Sub AddFrame(frame As M_WebSocket.Frame)
		  if self.Type = Types.Unknown then
		    mType = frame.Type
		    
		  elseif frame.Type = Types.Continuation then
		    //
		    // Do nothing
		    //
		    
		  elseif frame.Type <> self.Type then
		    raise new WebSocketException( "Frame type must match message type" )
		    
		  end if
		  
		  self.Content = self.Content + frame.Content
		  IsComplete = frame.IsFinal
		  
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub Constructor()
		  
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub Constructor(frame As M_WebSocket.Frame)
		  Constructor
		  AddFrame frame
		  
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		 Shared Function ControlTypes() As M_WebSocket.Message.Types()
		  dim r() as Message.Types = Array( _
		  Message.Types.Ping, _
		  Message.Types.Pong, _
		  Message.Types.ConnectionClose _
		  )
		  
		  return r
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		 Shared Function DataTypes() As Message.Types()
		  
		  dim r() as Message.Types = Array( _
		  Types.Binary, _
		  Types.Text _
		  )
		  
		  return r
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function NextFrame(limit As Integer) As M_WebSocket.Frame
		  if EOF then
		    return nil
		  end if
		  
		  if Message.ControlTypes.IndexOf( Type ) <> -1 then
		    //
		    // Cannot fragment a control message
		    //
		    limit = 125
		    
		  elseif limit <= 0 then
		    //
		    // We are sending the rest
		    //
		    limit = Content.LenB
		    
		  end if
		  
		  dim r as new M_WebSocket.Frame
		  
		  dim data as string = Content.MidB( FramePositionIndex, limit )
		  r.Type = if( FramePositionIndex = 1, Type, Message.Types.Continuation )
		  
		  FramePositionIndex = FramePositionIndex + data.LenB
		  
		  r.Content = data
		  r.IsFinal = EOF
		  r.IsMasked = UseMask
		  
		  return r
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub Reset()
		  FramePositionIndex = 1
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		 Shared Function ValidTypes() As Message.Types()
		  
		  dim r() as Message.Types = Array( _
		  Types.Binary, _
		  Types.Text, _
		  Types.Ping, _
		  Types.Pong, _
		  Types.ConnectionClose, _
		  Types.Continuation _
		   )
		  
		  return r
		End Function
	#tag EndMethod


	#tag ComputedProperty, Flags = &h0
		#tag Getter
			Get
			  if IsComplete and Type = Message.Types.Text and mContent.Encoding is nil then
			    mContent = mContent.DefineEncoding( Encodings.UTF8 )
			  end if
			  
			  return mContent
			End Get
		#tag EndGetter
		#tag Setter
			Set
			  mContent = value
			End Set
		#tag EndSetter
		Content As String
	#tag EndComputedProperty

	#tag ComputedProperty, Flags = &h0
		#tag Note
			return FramePositionIndex >
		#tag EndNote
		#tag Getter
			Get
			  return FramePositionIndex > Content.LenB
			End Get
		#tag EndGetter
		EOF As Boolean
	#tag EndComputedProperty

	#tag Property, Flags = &h21
		Private FramePositionIndex As Integer = 1
	#tag EndProperty

	#tag Property, Flags = &h0
		IsComplete As Boolean
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mContent As String
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mType As Types = Types.Unknown
	#tag EndProperty

	#tag ComputedProperty, Flags = &h0
		#tag Getter
			Get
			  return mType
			  
			End Get
		#tag EndGetter
		#tag Setter
			Set
			  if value = Types.Unknown or value = Types.Continuation then
			    raise new WebSocketException( "Cannot set a message to that type : " + str( value ) )
			  end if
			  
			  mType = value
			End Set
		#tag EndSetter
		Type As Message.Types
	#tag EndComputedProperty

	#tag Property, Flags = &h0
		UseMask As Boolean
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
			Name="mContent"
			Group="Behavior"
			Type="String"
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
