#tag Class
Private Class Frame
	#tag Method, Flags = &h0
		Shared Function Decode(dataMB as MemoryBlock) As M_WebSocket.Frame()
		  Dim frames() As M_WebSocket.Frame
		  Dim p As UInt64 = 0
		  While p < dataMB.Size
		    
		    dataMB.LittleEndian = False
		    Dim dataPtr As Ptr = dataMB
		    
		    Dim isFinal As Boolean = (dataPtr.Byte(p + 0) And &b10000000) <> 0
		    Dim opCode As Integer = dataPtr.Byte(p + 0) And &b01111111
		    Dim type As Message.Types = Message.Types(opCode)
		    
		    If Message.ValidTypes.IndexOf(type) = -1 Then
		      Raise New WebSocketException("Packet type is invalid")
		    End If
		    
		    Dim lenCode As Byte = dataPtr.Byte(p + 1)
		    Dim masked As Boolean = (lenCode And &b10000000) <> 0
		    lenCode = lenCode And &b01111111
		    
		    Dim dataLen As UInt64
		    Dim firstDataByte As Integer = p + 2
		    
		    Select Case lenCode
		    Case 127
		      dataLen = dataMB.UInt64Value(p + 2)
		      firstDataByte = firstDataByte + 8
		      
		    Case 126
		      dataLen = dataMB.UInt16Value(p + 2)
		      firstDataByte = firstDataByte + 2
		      
		    Case Else
		      dataLen = lenCode
		      
		    End Select
		    
		    Dim lastDataByte As Integer = firstDataByte + dataLen
		    
		    If masked And dataLen > 0 Then
		      Dim maskMB As MemoryBlock = dataMB.StringValue(firstDataByte, 4)
		      Dim maskPtr As Ptr = maskMB
		      
		      firstDataByte = firstDataByte + 4
		      
		      Dim maskIndex As Integer
		      For i As Integer = firstDataByte To lastDataByte
		        dataPtr.Byte(i) = dataPtr.Byte(i) Xor maskPtr.Byte(maskIndex)
		        
		        maskIndex = maskIndex + 1
		        If maskIndex = 4 Then
		          maskIndex = 0
		        End If
		      Next
		    End If
		    
		    Dim data As String = If(dataLen > 0, dataMB.StringValue(firstDataByte, lastDataByte - firstDataByte), "")
		    
		    If isFinal And type = Message.Types.Text Then
		      //
		      // Make sure it's UTF-8
		      //
		      If Not Encodings.UTF8.IsValidData(data) Then
		        Raise New WebSocketException("The data was not valid UTF-8")
		      End If
		      data = data.DefineEncoding(Encodings.UTF8)
		    End If
		    
		    Dim r As New M_WebSocket.Frame
		    
		    r.IsFinal = isFinal
		    r.Type = type
		    r.IsMasked = masked
		    r.Content = data
		    
		    frames.Append r
		    
		    p = lastDataByte
		  Wend
		  
		  Return frames
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Function Operator_Convert() As String
		  return ToString
		End Function
	#tag EndMethod


	#tag Property, Flags = &h0
		Content As String
	#tag EndProperty

	#tag Property, Flags = &h0
		IsFinal As Boolean = True
	#tag EndProperty

	#tag Property, Flags = &h0
		IsMasked As Boolean
	#tag EndProperty

	#tag ComputedProperty, Flags = &h0
		#tag Getter
			Get
			  dim finCodeNibble as byte = if( IsFinal, &b10000000, 0 )
			  dim opCodeNibble as byte = integer( Type )
			  dim firstByte as byte = finCodeNibble + opCodeNibble
			  
			  const uZero as UInt64 = 0
			  
			  dim useLength as UInt64 = content.LenB
			  dim lenCode as byte
			  
			  dim lenMB as MemoryBlock
			  select case useLength
			  case is > &hFFFF
			    lenMB = new MemoryBlock( 8 )
			    lenMB.LittleEndian = false
			    lenMB.UInt64Value( 0 ) = useLength
			    lenCode = 127
			    
			  case is > 125
			    lenMB = new MemoryBlock( 2 )
			    lenMB.LittleEndian = false
			    lenMB.UInt16Value( 0 ) = useLength
			    lenCode = 126
			    
			  case else
			    lenCode = useLength
			    
			  end select
			  
			  dim dataMB as MemoryBlock = Content
			  dim maskMB as MemoryBlock
			  
			  if IsMasked and Content <> "" then
			    lenCode = lenCode or &b10000000
			    
			    maskMB = Crypto.GenerateRandomBytes( 4 )
			    dim maskIndex as integer
			    dim lastByte as integer = dataMB.Size - 1
			    dim dataPtr as Ptr = dataMB
			    dim maskPtr as Ptr = maskMB
			    
			    for i as integer = 0 to lastByte
			      dataPtr.Byte( i ) = dataPtr.Byte( i ) xor maskPtr.Byte( maskIndex )
			      maskIndex = maskIndex + 1
			      if maskIndex = 4 then
			        maskIndex = 0
			      end if
			    next
			  end if
			  
			  //
			  // Assemble it all
			  //
			  
			  dim mask as string = if( maskMB isa Object, maskMB.StringValue( 0, maskMB.Size ), "" )
			  dim sendData as string = if( dataMB.Size > 0, dataMB.StringValue( 0, dataMB.Size ),  "" )
			  dim r as string = _
			  ChrB( firstByte ) + _
			  ChrB( lenCode ) + _
			  if( lenMB isa object, lenMB.StringValue( 0, lenMB.Size ), "" ) + _
			    mask + _
			    sendData
			    
			    return r
			    
			    
			End Get
		#tag EndGetter
		ToString As String
	#tag EndComputedProperty

	#tag Property, Flags = &h0
		Type As Message.Types = Message.Types.Unknown
	#tag EndProperty


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
			Name="IsFinal"
			Group="Behavior"
			InitialValue="True"
			Type="Boolean"
		#tag EndViewProperty
		#tag ViewProperty
			Name="IsMasked"
			Group="Behavior"
			Type="Boolean"
		#tag EndViewProperty
		#tag ViewProperty
			Name="Left"
			Visible=true
			Group="Position"
			InitialValue="0"
			Type="Integer"
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
		#tag ViewProperty
			Name="ToString"
			Group="Behavior"
			Type="String"
		#tag EndViewProperty
	#tag EndViewBehavior
End Class
#tag EndClass
