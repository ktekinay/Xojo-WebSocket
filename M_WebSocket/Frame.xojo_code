#tag Class
Private Class Frame
	#tag Method, Flags = &h0
		Shared Function Decode(dataMB As MemoryBlock, ByRef remainder As String) As M_WebSocket.Frame()
		  dim frames() as M_WebSocket.Frame
		  
		  dataMB.LittleEndian = False
		  dim dataPtr as ptr = dataMB
		  
		  dim offset as integer
		  
		  while offset < dataMB.Size
		    
		    dim isFinal as boolean = ( dataPtr.Byte( offset ) and &b10000000 ) <> 0
		    dim opCode as Integer = dataPtr.Byte( offset ) and &b01111111
		    dim type as Message.Types = Message.Types( opCode )
		    
		    if Message.ValidTypes.IndexOf( type ) = -1 then
		      raise new WebSocketException( "Packet type is invalid" )
		    end if
		    
		    dim lenCode as Byte = dataPtr.Byte( offset + 1 )
		    dim masked as boolean = ( lenCode and &b10000000 ) <> 0
		    lenCode = lenCode and &b01111111
		    
		    dim dataLen as UInt64
		    dim firstDataByte as Integer = offset + 2
		    
		    select case lenCode
		    case 127
		      dataLen = dataMB.UInt64Value( offset + 2 )
		      firstDataByte = firstDataByte + 8
		      
		    case 126
		      dataLen = dataMB.UInt16Value( offset + 2 )
		      firstDataByte = firstDataByte + 2
		      
		    case else
		      dataLen = lenCode
		      
		    end select
		    
		    dim lastDataByte as Integer = firstDataByte + dataLen
		    
		    if masked and dataLen > 0 then
		      dim maskMB as MemoryBlock = dataMB.StringValue( firstDataByte, 4 )
		      dim maskPtr as ptr = maskMB
		      
		      firstDataByte = firstDataByte + 4
		      
		      dim maskIndex as Integer
		      for i as Integer = firstDataByte to lastDataByte
		        dataPtr.Byte( i ) = dataPtr.Byte( i ) xor maskPtr.Byte( maskIndex )
		        
		        maskIndex = maskIndex + 1
		        if maskIndex = 4 then
		          maskIndex = 0
		        end if
		      next
		    end if
		    
		    dim data as String
		    if dataLen = 0 then
		      data = ""
		    else
		      dim requiredDataLen as integer = lastDataByte - firstDataByte
		      dim remainingDataLen as integer = dataMB.Size - firstDataByte
		      
		      if remainingDataLen < requiredDataLen then
		        //
		        // Not enough data left
		        //
		        if DebugBuild then
		          System.DebugLog "Partial Packet: " + format( requiredDataLen, "#,0" ) + " bytes required, " +_
		          format( remainingDataLen, "#,0" ) + " bytes available"
		        end if
		        
		        exit while
		      end if
		      
		      data = dataMB.StringValue( firstDataByte, requiredDataLen )
		    end if
		    
		    if isFinal and type = Message.Types.Text then
		      //
		      // Make sure it's UTF-8
		      //
		      if not Encodings.UTF8.IsValidData( data ) then
		        raise new WebSocketException( "The data was not valid UTF-8" )
		      end if
		      data = data.DefineEncoding( Encodings.UTF8 )
		    end if
		    
		    dim r as new M_WebSocket.Frame
		    
		    r.isFinal = isFinal
		    r.type = type
		    r.IsMasked = masked
		    r.Content = data
		    
		    frames.Append r
		    
		    offset = lastDataByte
		  wend
		  
		  //
		  // Set the remainder
		  //
		  if offset < dataMB.Size then
		    remainder = dataMB.StringValue( offset, dataMB.Size - offset )
		  else
		    remainder = ""
		  end if
		  
		  return frames
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
			EditorType="MultiLineEditor"
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
			EditorType="MultiLineEditor"
		#tag EndViewProperty
	#tag EndViewBehavior
End Class
#tag EndClass
