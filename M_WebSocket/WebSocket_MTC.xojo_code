#tag Class
Class WebSocket_MTC
Inherits SSLSocket
Implements Writeable
	#tag Event
		Sub Connected()
		  //
		  // Do substitutions
		  //
		  dim key as string = Crypto.GenerateRandomBytes( 16 )
		  key = EncodeBase64( key )
		  
		  ConnectKey = key
		  
		  dim header as string = kGetHeader
		  
		  dim resources as string = URL.Resource
		  if URL.Parameters.Count <> 0 then
		    resources = resources + "?" + URL.ParametersToString
		  end if
		  
		  header = header.Replace( "%RESOURCES%", resources )
		  header = header.Replace( "%HOST%", URL.Host )
		  header = header.Replace( "%KEY%", key )
		  
		  if Origin.Trim <> "" then
		    header = header + "Origin: " + Origin + EndOfLine
		  end if
		  
		  if RequestProtocols.Ubound <> -1 then
		    for i as integer = 0 to RequestProtocols.Ubound
		      RequestProtocols( i ) = RequestProtocols( i ).Trim
		    next
		    header = header + kHeaderProtocol + ": " + join( RequestProtocols, ", " ) + EndOfLine
		  end if
		  
		  header = header + EndOfLine
		  header = ReplaceLineEndings( header, EndOfLine.Windows )
		  super.Write header
		  
		  #if false then
		    //
		    // The constant, for convenience
		    //
		    GET /%RESOURCES% HTTP/1.1
		    Connection: Upgrade
		    Host: %HOST%
		    Sec-WebSocket-Key: %KEY%
		    Upgrade: websocket
		    Sec-WebSocket-Version: 13
		    
		  #endif
		End Sub
	#tag EndEvent

	#tag Event
		Sub DataAvailable()
		  dim data as string = ReadAll
		  
		  if State = States.Connected then
		    
		    dim f as M_WebSocket.Frame = M_WebSocket.Frame.Decode( data )
		    if f is nil then
		      RaiseEvent Error( "Invalid packet received" )
		      return
		    end if
		    
		    select case f.Type
		    case Message.Types.Ping
		      
		      dim response as new M_WebSocket.Frame
		      response.Content = f.Content
		      response.Type = Message.Types.Pong
		      response.IsMasked = UseMask
		      response.IsFinal = true
		      
		      OutgoingControlFrames.Append response
		      SendNextFrame
		      
		    case Message.Types.ConnectionClose
		      if RequestedDisconnect then
		        //
		        // This is in response to our message
		        //
		        super.Disconnect
		        mState = States.Disconnected
		      else
		        //
		        // Server is requesting a disconnect
		        //
		        Disconnect
		      end if
		    case Message.Types.Pong
		      RaiseEvent PongReceived( f.Content.DefineEncoding( Encodings.UTF8 ) )
		      
		    case Message.Types.Continuation
		      if IncomingMessage is nil then
		        RaiseEvent Error( "A continuation packet was received out of order" )
		        
		      else
		        IncomingMessage.AddFrame( f )
		        
		        if IncomingMessage.IsComplete then
		          RaiseEvent DataAvailable( IncomingMessage.Content )
		          IncomingMessage = nil
		        end if
		      end if
		      
		    case else
		      if IncomingMessage isa Object then
		        RaiseEvent Error( "A new packet arrived before the previous message was completed" )
		        
		      else
		        if f.IsFinal then
		          dim content as string = f.Content
		          if f.Type = Message.Types.Text then
		            content = content.DefineEncoding( Encodings.UTF8 )
		          end if
		          
		          RaiseEvent DataAvailable( content )
		        else
		          IncomingMessage = new M_WebSocket.Message( f )
		        end if
		      end if
		      
		    end select
		    
		  elseif State = States.Connecting then
		    //
		    // Still handling the negotiation
		    //
		    
		    if ValidateHandshake( data ) then
		      mState = States.Connected
		      RaiseEvent Connected
		    else
		      Close
		      mState = States.Disconnected
		    end if
		    
		  end if
		  
		  return
		End Sub
	#tag EndEvent

	#tag Event
		Sub Error()
		  if LastErrorCode = 102 then
		    
		    RaiseEvent Disconnected
		    
		  else
		    
		    dim data as string = ReadAll
		    RaiseEvent Error( data )
		    
		  end if
		  
		  return
		End Sub
	#tag EndEvent


	#tag Method, Flags = &h0
		Sub Connect(url As Text)
		  if State = States.Connected then
		    raise new WebSocketException( "The WebSocket is already connected" )
		  end if
		  
		  dim urlComps as new M_WebSocket.URLComponents( url.Trim )
		  
		  dim rx as new RegEx
		  rx.SearchPattern = "^(?:http|ws)s:"
		  
		  Address = urlComps.Host
		  if urlComps.Port > 0 then
		    
		    Port = urlComps.Port
		    Secure = rx.Search( urlComps.Protocol ) isa RegExMatch
		    
		  else
		    
		    if rx.Search( urlComps.Protocol ) isa RegExMatch then
		      Secure = true
		    else
		      Secure = false
		    end if
		    
		  end if
		  
		  if Port <= 0 then
		    if Secure then
		      Port = 443
		    else
		      Port = 80
		    end if
		  end if
		  
		  self.URL = urlComps
		  
		  AcceptedProtocol = ""
		  IsServer = false
		  RequestedDisconnect = false
		  super.Connect
		  mState = States.Connecting
		  
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub Constructor()
		  super.Constructor
		  
		  SendTimer = new Timer
		  SendTimer.Mode = Timer.ModeOff
		  SendTimer.Period = 20
		  
		  AddHandler SendTimer.Action, WeakAddressOf SendTimer_Action
		  
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Sub Destructor()
		  if SendTimer isa Timer then
		    SendTimer.Mode = Timer.ModeOff
		    RemoveHandler SendTimer.Action, WeakAddressOf SendTimer_Action
		    SendTimer = nil
		  end if
		  
		  Close
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub Disconnect()
		  if State = States.Connected then
		    dim f as new M_WebSocket.Frame
		    f.Type = Message.Types.ConnectionClose
		    f.IsFinal = true
		    
		    RequestedDisconnect = true
		    
		    redim OutgoingControlFrames( -1 )
		    redim OutgoingUserMessages( -1 )
		    OutgoingControlFrames.Append f
		    SendNextFrame
		    
		    mState = States.Disconnecting
		    
		  elseif IsConnected then
		    super.Disconnect
		  end if
		  
		  //
		  // The server should respond and 
		  // disconnect
		  //
		  
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub Listen()
		  IsServer = true
		  super.Listen
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub Ping(msg As String = "")
		  dim f as new M_WebSocket.Frame
		  f.Content = msg
		  f.IsFinal = true
		  f.IsMasked = UseMask
		  f.Type = Message.Types.Ping
		  
		  OutgoingControlFrames.Append f
		  SendNextFrame
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Sub SendNextFrame()
		  if State <> States.Connected then
		    redim OutgoingUserMessages( -1 )
		    redim OutgoingControlFrames( -1 )
		    SendTimer.Mode = Timer.ModeOff
		    return
		  end if
		  
		  //
		  // Send any control frames first
		  //
		  
		  if OutgoingControlFrames.Ubound <> -1 then
		    dim f as M_WebSocket.Frame = OutgoingControlFrames( 0 )
		    OutgoingControlFrames.Remove 0
		    
		    super.Write f.ToString
		    
		  elseif OutgoingUserMessages.Ubound <> -1 then
		    dim m as M_WebSocket.Message = OutgoingUserMessages( 0 )
		    
		    dim f as M_WebSocket.Frame = m.NextFrame( ContentLimit )
		    if f isa Object then
		      super.Write f.ToString
		    end if
		    
		    //
		    // See if the last frame from this message has been sent
		    //
		    if m.EOF then
		      OutgoingUserMessages.Remove 0
		    end if
		    
		  end if
		  
		  if SendTimer.Mode = Timer.ModeOff and _
		    ( OutgoingUserMessages.Ubound <> -1 or OutgoingUserMessages.Ubound <> -1 ) then
		    SendTimer.Mode = Timer.ModeMultiple
		  end if
		  
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Sub SendTimer_Action(sender As Timer)
		  SendNextFrame
		  
		  if OutgoingUserMessages.Ubound = -1 and OutgoingControlFrames.Ubound = -1 then
		    sender.Mode = Timer.ModeOff
		  end if
		  
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Function ValidateHandshake(data As String) As Boolean
		  const kErrorPrefix = "Could not negotiate connection: "
		  
		  data = data.DefineEncoding( Encodings.UTF8 )
		  data = ReplaceLineEndings( data, &uA )
		  
		  dim rx as new RegEx
		  
		  //
		  // Confirm the status code
		  //
		  rx.SearchPattern = "\AHTTP/\d+(?:\.\d+) (\d+)"
		  dim match as RegExMatch = rx.Search( data )
		  
		  if match is nil then
		    RaiseEvent Error kErrorPrefix + "The data returned by the server did not make sense"
		    return false
		  end if
		  
		  dim responseCode as integer = match.SubExpressionString( 1 ).Val
		  select case responseCode
		  case 101
		    //
		    // Great, proceed
		    //
		    
		  case else
		    RaiseEvent Error kErrorPrefix + "Could not handle the response code " + str( responseCode ) + " returned by the server"
		    return false
		    
		  end select
		  
		  //
		  // Parse the headers
		  //
		  rx.SearchPattern = "^([^: ]+):? *(.*)"
		  
		  dim headers as new Dictionary
		  match = rx.Search( data )
		  while match isa RegExMatch
		    dim key as string = match.SubExpressionString( 1 )
		    dim value as string = match.SubExpressionString( 2 )
		    headers.Value( key ) = value
		    
		    match = rx.Search
		  wend
		  
		  //
		  // Validate the required headers
		  //
		  if headers.Lookup( "Upgrade", "" ) <> "websocket" or _
		    headers.Lookup( "Connection", "" ) <> "Upgrade" then
		    RaiseEvent Error kErrorPrefix + "Missing header keys Upgrade and/or Connection"
		    return false
		  end if
		  
		  //
		  // Validate Sec-WebSocket-Accept if present
		  //
		  const kGUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
		  
		  dim returnedKey as string = headers.Lookup( kHeaderSecAcceptKey, "" ).StringValue.Trim
		  if returnedKey = "" then
		    RaiseEvent Error kErrorPrefix + "Missing " + kHeaderSecAcceptKey
		    return false
		  end if
		  
		  dim expectedKey as string = EncodeBase64( Crypto.SHA1( ConnectKey + kGUID ) )
		  
		  if expectedKey <> returnedKey then
		    RaiseEvent Error kErrorPrefix + "The " + kHeaderSecAcceptKey + " header contained an incorrect value"
		    return false
		  end if
		  
		  //
		  // If we get here, all the validation passed
		  //
		  
		  if headers.HasKey( kHeaderProtocol ) then
		    AcceptedProtocol = headers.Value( kHeaderProtocol )
		    if RequestProtocols.IndexOf( AcceptedProtocol ) = -1 then
		      //
		      // Some other protocol
		      //
		      RaiseEvent Error kErrorPrefix + "The server accepted protocol " + AcceptedProtocol + " but that was not requested"
		      return false
		    end if
		  end if
		  
		  return true
		  
		End Function
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub Write(data As String)
		  dim m as new M_WebSocket.Message
		  m.Content = data
		  m.Type = if( data.Encoding is nil, Message.Types.Binary, Message.Types.Text )
		  m.UseMask = UseMask
		  
		  OutgoingUserMessages.Append m
		  SendNextFrame
		End Sub
	#tag EndMethod


	#tag Hook, Flags = &h0
		Event Connected()
	#tag EndHook

	#tag Hook, Flags = &h0
		Event DataAvailable(data As String)
	#tag EndHook

	#tag Hook, Flags = &h0
		Event Disconnected()
	#tag EndHook

	#tag Hook, Flags = &h0
		Event Error(message As String)
	#tag EndHook

	#tag Hook, Flags = &h0
		Event PongReceived(msg As String)
	#tag EndHook


	#tag Property, Flags = &h0
		AcceptedProtocol As String
	#tag EndProperty

	#tag Property, Flags = &h21
		Private ConnectKey As String
	#tag EndProperty

	#tag Property, Flags = &h0
		ContentLimit As Integer = 32767
	#tag EndProperty

	#tag Property, Flags = &h21
		Private IncomingMessage As M_WebSocket.Message
	#tag EndProperty

	#tag Property, Flags = &h21
		Private IsServer As Boolean
	#tag EndProperty

	#tag Property, Flags = &h21
		Private mState As States
	#tag EndProperty

	#tag Property, Flags = &h0
		Origin As String
	#tag EndProperty

	#tag Property, Flags = &h21
		Private OutgoingControlFrames() As M_WebSocket.Frame
	#tag EndProperty

	#tag Property, Flags = &h21
		Private OutgoingUserMessages() As M_WebSocket.Message
	#tag EndProperty

	#tag Property, Flags = &h21
		Private RequestedDisconnect As Boolean
	#tag EndProperty

	#tag Property, Flags = &h0
		RequestProtocols() As String
	#tag EndProperty

	#tag Property, Flags = &h21
		Private SendTimer As Timer
	#tag EndProperty

	#tag ComputedProperty, Flags = &h0
		#tag Getter
			Get
			  if not IsConnected then
			    mState = States.Disconnected
			  end if
			  
			  return mState
			  
			End Get
		#tag EndGetter
		State As States
	#tag EndComputedProperty

	#tag Property, Flags = &h21
		Private URL As M_WebSocket.URLComponents
	#tag EndProperty

	#tag ComputedProperty, Flags = &h21
		#tag Getter
			Get
			  return not IsServer
			End Get
		#tag EndGetter
		Private UseMask As Boolean
	#tag EndComputedProperty


	#tag Constant, Name = kGetHeader, Type = String, Dynamic = False, Default = \"GET /%RESOURCES% HTTP/1.1\nConnection: Upgrade\nHost: %HOST%\nSec-WebSocket-Key: %KEY%\nUpgrade: websocket\nSec-WebSocket-Version: 13\n", Scope = Private
	#tag EndConstant

	#tag Constant, Name = kHeaderProtocol, Type = String, Dynamic = False, Default = \"Sec-WebSocket-Protocol", Scope = Private
	#tag EndConstant

	#tag Constant, Name = kHeaderSecAcceptKey, Type = String, Dynamic = False, Default = \"Sec-WebSocket-Accept", Scope = Private
	#tag EndConstant

	#tag Constant, Name = kHeaderSecKey, Type = String, Dynamic = False, Default = \"Sec-WebSocket-Key", Scope = Private
	#tag EndConstant


	#tag Enum, Name = States, Type = Integer, Flags = &h0
		Disconnected
		  Connecting
		  Connected
		Disconnecting
	#tag EndEnum


	#tag ViewBehavior
		#tag ViewProperty
			Name="AcceptedProtocol"
			Group="Behavior"
			Type="String"
			EditorType="MultiLineEditor"
		#tag EndViewProperty
		#tag ViewProperty
			Name="CertificateFile"
			Group="Behavior"
			Type="FolderItem"
			EditorType="File"
		#tag EndViewProperty
		#tag ViewProperty
			Name="CertificatePassword"
			Visible=true
			Group="Behavior"
			Type="String"
		#tag EndViewProperty
		#tag ViewProperty
			Name="CertificateRejectionFile"
			Group="Behavior"
			Type="FolderItem"
			EditorType="File"
		#tag EndViewProperty
		#tag ViewProperty
			Name="ConnectionType"
			Visible=true
			Group="Behavior"
			InitialValue="3"
			Type="Integer"
		#tag EndViewProperty
		#tag ViewProperty
			Name="ContentLimit"
			Visible=true
			Group="Behavior"
			InitialValue="&h7FFF"
			Type="Integer"
		#tag EndViewProperty
		#tag ViewProperty
			Name="ForceMasked"
			Visible=true
			Group="Behavior"
			Type="Boolean"
		#tag EndViewProperty
		#tag ViewProperty
			Name="Index"
			Visible=true
			Group="ID"
			Type="Integer"
			EditorType="Integer"
		#tag EndViewProperty
		#tag ViewProperty
			Name="Name"
			Visible=true
			Group="ID"
			Type="String"
			EditorType="String"
		#tag EndViewProperty
		#tag ViewProperty
			Name="Origin"
			Visible=true
			Group="Behavior"
			Type="String"
			EditorType="MultiLineEditor"
		#tag EndViewProperty
		#tag ViewProperty
			Name="Secure"
			Visible=true
			Group="Behavior"
			Type="Boolean"
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
				"3 - Disconnecting"
			#tag EndEnumValues
		#tag EndViewProperty
		#tag ViewProperty
			Name="Super"
			Visible=true
			Group="ID"
			Type="String"
			EditorType="String"
		#tag EndViewProperty
	#tag EndViewBehavior
End Class
#tag EndClass
