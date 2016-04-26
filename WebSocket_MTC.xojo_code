#tag Class
Protected Class WebSocket_MTC
Implements Writeable
	#tag Method, Flags = &h0
		Sub Connect(url As Text)
		  #pragma warning "If aleady connected, raise an exception"
		  
		  dim rx as new RegEx
		  rx.SearchPattern = "^(?:http|ws)s:"
		  
		  CreateSocket
		  
		  url = url.Trim
		  Socket.Address = url
		  if rx.Search( url ) isa RegExMatch then
		    Socket.Secure = true
		    Socket.Port = 443
		  else
		    Socket.Secure = false
		    Socket.Port = 80
		  end if
		  
		  self.URL = url
		  
		  Socket.Connect
		  mState = States.Connecting
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Sub CreateSocket()
		  if Socket is nil then
		    Socket = new SSLSocket
		    
		    AddHandler Socket.Connected, WeakAddressOf Socket_Connected
		    AddHandler Socket.Error, WeakAddressOf Socket_Error
		    AddHandler Socket.DataAvailable, WeakAddressOf Socket_DataAvailable
		    AddHandler Socket.SendComplete, WeakAddressOf Socket_SendComplete
		    AddHandler Socket.SendProgress, WeakAddressOf Socket_SendProgress
		    
		  end if
		  
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function DecodePacket(dataMB as MemoryBlock) As Pair
		  dim r as Pair
		  
		  if dataMB.Size = 0 then
		    return r
		  end if
		  
		  dataMB.LittleEndian = false
		  dim dataPtr as Ptr = dataMB
		  dim lastDataByte as integer = dataMB.Size - 1
		  
		  dim type as PacketTypes = PacketTypes( dataPtr.Byte( 0 ) and &b01111111 )
		  dim lenCode as byte = dataPtr.Byte( 1 )
		  dim masked as boolean = ( lenCode and &b10000000 ) <> 0
		  lenCode = lenCode and &b01111111
		  
		  dim dataLen as UInt64
		  dim firstDataByte as integer = 2 
		  
		  select case lenCode
		  case 127
		    dataLen = dataMB.UInt64Value( 2 )
		    firstDataByte = firstDataByte + 8
		    
		  case 126
		    dataLen = dataMB.UInt16Value( 2 )
		    firstDataByte = firstDataByte + 2
		    
		  case else
		    dataLen = lenCode
		    
		  end select
		  
		  if masked and dataLen > 0 then
		    dim maskMB as MemoryBlock = dataMB.StringValue( firstDataByte, 4 )
		    dim maskPtr as Ptr = maskMB
		    
		    firstDataByte = firstDataByte + 4
		    
		    dim maskIndex as integer
		    for i as integer = firstDataByte to lastDataByte
		      dataPtr.Byte( i ) = dataPtr.Byte( i ) xor maskPtr.Byte( maskIndex )
		      
		      maskIndex = maskIndex + 1
		      if maskIndex = 4 then
		        maskIndex = 0
		      end if
		    next
		  end if
		  
		  dim data as string = if( dataLen > 0, dataMB.StringValue( firstDataByte, lastDataByte - firstDataByte + 1 ), "" )
		  
		  r = type : data
		  return r
		End Function
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Sub DestroySocket()
		  if Socket isa Object then
		    RemoveHandler Socket.Connected, WeakAddressOf Socket_Connected
		    RemoveHandler Socket.Error, WeakAddressOf Socket_Error
		    RemoveHandler Socket.DataAvailable, WeakAddressOf Socket_DataAvailable
		    RemoveHandler Socket.SendComplete, WeakAddressOf Socket_SendComplete
		    RemoveHandler Socket.SendProgress, WeakAddressOf Socket_SendProgress
		    Socket.Close
		    
		    Socket = nil
		  end if
		  
		  mState = States.Disconnected
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Sub Destructor()
		  DestroySocket
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub Disconnect()
		  //
		  // THIS IS FOR EXTERNAL USE ONLY
		  // 
		  // Do not use internally
		  //
		  
		  if Socket isa Object then
		    if State = States.Connected then
		      dim packet as string = EncodePacket( "Disconnecton requested", PacketTypes.ConnectionClose, UseMasked )
		      Socket.Write packet
		    end if
		    
		    //
		    // The server should respond and 
		    // disconnect
		    //
		  end if
		  
		  
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function EncodePacket(data As String, packetType As PacketTypes, masked As Boolean, useLength As UInt64 = 0) As String
		  dim finCodeNibble as byte = if( packetType = PacketTypes.Continuation, 0, &b10000000 )
		  dim opCodeNibble as byte = integer( packetType )
		  dim firstByte as byte = finCodeNibble + opCodeNibble
		  
		  const uZero as UInt64 = 0
		  
		  if packetType = PacketTypes.Continuation then
		    useLength = uZero
		  elseif useLength = uZero then
		    useLength = data.LenB
		  end if
		  
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
		  
		  dim dataMB as MemoryBlock = data
		  dim maskMB as MemoryBlock
		  
		  if masked and data <> "" then
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
		  mask + _
		  sendData
		  
		  return r
		  
		  
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub Flush()
		  if Socket isa Object then
		    Socket.Flush
		  end if
		  
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Sub Socket_Connected(sender As SSLSocket)
		  //
		  // Do substitutions
		  //
		  dim rxHost as new RegEx
		  rxHost.SearchPattern = "^([^:]+://)?(.*)"
		  rxHost.ReplacementPattern = "$2"
		  
		  dim host as string = URL
		  host = rxHost.Replace( host )
		  
		  dim key as string = Crypto.GenerateRandomBytes( 10 )
		  key = EncodeBase64( key )
		  
		  dim header as string = kGetHeader
		  header = header.Replace( "%ORIGIN%", sender.LocalAddress )
		  header = header.Replace( "%HOST%", host )
		  header = header.Replace( "%KEY%", key )
		  
		  header = ReplaceLineEndings( header, EndOfLine.Windows )
		  sender.Write header
		  
		  #if false then
		    //
		    // The constant, for convenience
		    //
		    GET / HTTP/1.1
		    Origin: %ORIGIN%
		    Connection: Upgrade
		    Host: %HOST%
		    Sec-WebSocket-Key: %KEY%
		    Upgrade: websocket
		    Sec-WebSocket-Version: 13
		    
		    
		  #endif
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Sub Socket_DataAvailable(sender As SSLSocket)
		  dim data as string = sender.ReadAll
		  
		  if State = States.Connected then
		    dim parts as Pair = DecodePacket( data )
		    dim type as PacketTypes = parts.Left
		    data = parts.Right
		    
		    select case type
		    case PacketTypes.Ping
		      
		      dim packet as string = EncodePacket( data, PacketTypes.Pong, UseMasked )
		      Socket.Write packet
		      
		    case PacketTypes.ConnectionClose
		      DestroySocket
		      RaiseEvent Disconnected
		      
		    case PacketTypes.Pong
		      #pragma warning "Implement ping method and pong event, or something"
		      
		    case PacketTypes.Continuation
		      #pragma warning "Implement continuation handling"
		      
		    case else
		      
		      RaiseEvent ResponseReceived( data )
		      
		    end select
		    
		  elseif State = States.Connecting then
		    //
		    // Still handling the negotiation
		    //
		    
		    data = data.DefineEncoding( Encodings.UTF8 )
		    data = ReplaceLineEndings( data, &uA )
		    
		    dim rx as new RegEx
		    rx.SearchPattern = "^([^: ]+):? *(.*)"
		    
		    dim headers as new Dictionary
		    dim match as RegExMatch = rx.Search( data )
		    while match isa RegExMatch
		      dim key as string = match.SubExpressionString( 1 )
		      dim value as string = match.SubExpressionString( 2 )
		      headers.Value( key ) = value
		      
		      match = rx.Search
		    wend
		    
		    if headers.Lookup( "Upgrade", "" ) = "websocket" and headers.Lookup( "Connection", "" ) = "Upgrade" then
		      mState = States.Connected
		      RaiseEvent Connected
		    else
		      DestroySocket
		      mState = States.Disconnected
		      RaiseEvent Error( "Could not negotiate connection" )
		    end if
		    
		    headers = headers
		  end if
		  
		  return
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Sub Socket_Error(sender As SSLSocket)
		  if sender.LastErrorCode = 102 then
		    
		    DestroySocket
		    RaiseEvent Disconnected
		    
		  else
		    
		    dim data as string = sender.ReadAll
		    RaiseEvent Error( data )
		    
		  end if
		  
		  return
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Sub Socket_SendComplete(sender As SSLSocket, userAborted As Boolean)
		  
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function Socket_SendProgress(sender As SSLSocket, bytesSent As Integer, bytesLeft As Integer) As Boolean
		  if State = States.Connected then
		    return RaiseEvent SendProgress( bytesSent, bytesLeft )
		  end if
		  
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub Write(data As String)
		  if State = States.Connected and Socket isa object then
		    dim packet as string = EncodePacket( data, PacketTypes.Text, UseMasked )
		    Socket.Write packet
		  else
		    #pragma warning "Raise an exception?"
		  end if
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Function WriteError() As Boolean
		  if Socket isa Object then
		    return Socket.WriteError
		  end if
		  
		End Function
	#tag EndMethod


	#tag Hook, Flags = &h0
		Event Connected()
	#tag EndHook

	#tag Hook, Flags = &h0
		Event Disconnected()
	#tag EndHook

	#tag Hook, Flags = &h0
		Event Error(message As String)
	#tag EndHook

	#tag Hook, Flags = &h0
		Event ResponseReceived(data As String)
	#tag EndHook

	#tag Hook, Flags = &h0
		Event SendProgress(bytesSent As Integer, bytesLeft As Integer) As Boolean
	#tag EndHook


	#tag Property, Flags = &h0
		ForceMasked As Boolean
	#tag EndProperty

	#tag Property, Flags = &h21
		Private IsServer As Boolean
	#tag EndProperty

	#tag ComputedProperty, Flags = &h0
		#tag Getter
			Get
			  if Socket isa Object then
			    return Socket.LocalAddress
			  end if
			End Get
		#tag EndGetter
		LocalAddress As String
	#tag EndComputedProperty

	#tag Property, Flags = &h21
		Private mState As States
	#tag EndProperty

	#tag ComputedProperty, Flags = &h0
		#tag Getter
			Get
			  if Socket isa Object then
			    return Socket.RemoteAddress
			  end if
			  
			End Get
		#tag EndGetter
		RemoteAddress As String
	#tag EndComputedProperty

	#tag Property, Flags = &h21
		Private Socket As SSLSocket
	#tag EndProperty

	#tag ComputedProperty, Flags = &h0
		#tag Getter
			Get
			  if Socket is nil or not Socket.IsConnected then
			    mState = States.Disconnected
			  end if
			  
			  return mState
			  
			End Get
		#tag EndGetter
		State As States
	#tag EndComputedProperty

	#tag Property, Flags = &h21
		Private URL As String
	#tag EndProperty

	#tag ComputedProperty, Flags = &h21
		#tag Getter
			Get
			  return ForceMasked or not IsServer
			End Get
		#tag EndGetter
		Private UseMasked As Boolean
	#tag EndComputedProperty


	#tag Constant, Name = kGetHeader, Type = String, Dynamic = False, Default = \"GET / HTTP/1.1\nOrigin: %ORIGIN%\nConnection: Upgrade\nHost: %HOST%\nSec-WebSocket-Key: %KEY%\nUpgrade: websocket\nSec-WebSocket-Version: 13\n\n", Scope = Private
	#tag EndConstant


	#tag Enum, Name = PacketTypes, Type = Integer, Flags = &h21
		Continuation = 0
		  Text = 1
		  Binary = 2
		  ConnectionClose = 8
		  Ping = 9
		Pong = 10
	#tag EndEnum

	#tag Enum, Name = States, Type = Integer, Flags = &h0
		Disconnected
		  Connecting
		Connected
	#tag EndEnum


	#tag ViewBehavior
		#tag ViewProperty
			Name="ForceMasked"
			Group="Behavior"
			Type="Boolean"
		#tag EndViewProperty
		#tag ViewProperty
			Name="Index"
			Visible=true
			Group="ID"
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
			Name="LocalAddress"
			Group="Behavior"
			Type="String"
			EditorType="MultiLineEditor"
		#tag EndViewProperty
		#tag ViewProperty
			Name="Name"
			Visible=true
			Group="ID"
			Type="String"
		#tag EndViewProperty
		#tag ViewProperty
			Name="RemoteAddress"
			Group="Behavior"
			Type="String"
			EditorType="MultiLineEditor"
		#tag EndViewProperty
		#tag ViewProperty
			Name="State"
			Group="Behavior"
			Type="States"
			EditorType="Enum"
			#tag EnumValues
				"0 - Disconnected"
				"1 - Connecting"
				"2 - Connected"
			#tag EndEnumValues
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
