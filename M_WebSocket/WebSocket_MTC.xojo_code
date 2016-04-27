#tag Class
Class WebSocket_MTC
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

	#tag Method, Flags = &h0
		Sub Constructor()
		  SendTimer = new Timer
		  SendTimer.Mode = Timer.ModeOff
		  SendTimer.Period = 20
		  
		  AddHandler SendTimer.Action, WeakAddressOf SendTimer_Action
		  
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
		  
		  redim OutgoingControlFrames( -1 )
		  redim OutgoingUserMessages( -1 )
		  SendTimer.Mode = Timer.ModeOff
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h21
		Private Sub Destructor()
		  DestroySocket
		  
		  if SendTimer isa Timer then
		    SendTimer.Mode = Timer.ModeOff
		    RemoveHandler SendTimer.Action, WeakAddressOf SendTimer_Action
		    SendTimer = nil
		  end if
		  
		  
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
		      dim f as new M_WebSocket.Frame
		      f.Type = Message.Types.ConnectionClose
		      f.IsFinal = true
		      
		      OutgoingControlFrames.Append f
		      SendNextFrame
		    end if
		    
		    //
		    // The server should respond and 
		    // disconnect
		    //
		  end if
		  
		  
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub Flush()
		  if Socket isa Object then
		    Socket.Flush
		  end if
		  
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
		    
		    Socket.Write f.ToString
		    
		  elseif OutgoingUserMessages.Ubound <> -1 then
		    dim m as M_WebSocket.Message = OutgoingUserMessages( 0 )
		    
		    dim f as M_WebSocket.Frame = m.NextFrame( ContentLimit )
		    if f isa Object then
		      Socket.Write f.ToString
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
		      DestroySocket
		      RaiseEvent Disconnected
		      
		    case Message.Types.Pong
		      RaiseEvent PongReceived( f.Content.DefineEncoding( Encodings.UTF8 ) )
		      
		    case Message.Types.Continuation
		      if IncomingMessage is nil then
		        RaiseEvent Error( "A continuation packet was received out of order" )
		        
		      else
		        IncomingMessage.AddFrame( f )
		        
		        if IncomingMessage.IsComplete then
		          RaiseEvent DataReceived( IncomingMessage.Content )
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
		          
		          RaiseEvent DataReceived( content )
		        else
		          IncomingMessage = new M_WebSocket.Message( f )
		        end if
		      end if
		      
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
		  dim m as new M_WebSocket.Message
		  m.Content = data
		  m.Type = if( data.Encoding is nil, Message.Types.Binary, Message.Types.Text )
		  m.UseMask = UseMask
		  
		  OutgoingUserMessages.Append m
		  SendNextFrame
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
		Event DataReceived(data As String)
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

	#tag Hook, Flags = &h0
		Event SendProgress(bytesSent As Integer, bytesLeft As Integer) As Boolean
	#tag EndHook


	#tag Property, Flags = &h0
		ContentLimit As Integer = &h7FFF
	#tag EndProperty

	#tag Property, Flags = &h0
		ForceMasked As Boolean
	#tag EndProperty

	#tag Property, Flags = &h21
		Private IncomingMessage As M_WebSocket.Message
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

	#tag Property, Flags = &h21
		Private OutgoingControlFrames() As M_WebSocket.Frame
	#tag EndProperty

	#tag Property, Flags = &h21
		Private OutgoingUserMessages() As M_WebSocket.Message
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
		Private SendTimer As Timer
	#tag EndProperty

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
		Private UseMask As Boolean
	#tag EndComputedProperty


	#tag Constant, Name = kGetHeader, Type = String, Dynamic = False, Default = \"GET / HTTP/1.1\nOrigin: %ORIGIN%\nConnection: Upgrade\nHost: %HOST%\nSec-WebSocket-Key: %KEY%\nUpgrade: websocket\nSec-WebSocket-Version: 13\n\n", Scope = Private
	#tag EndConstant


	#tag Enum, Name = States, Type = Integer, Flags = &h0
		Disconnected
		  Connecting
		Connected
	#tag EndEnum


	#tag ViewBehavior
		#tag ViewProperty
			Name="ContentLimit"
			Group="Behavior"
			InitialValue="&h7FFF"
			Type="Integer"
		#tag EndViewProperty
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
