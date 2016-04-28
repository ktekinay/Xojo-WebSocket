#tag Class
Protected Class URLComponents
	#tag Method, Flags = &h0
		Sub Constructor()
		  
		End Sub
	#tag EndMethod

	#tag Method, Flags = &h0
		Sub Constructor(url As String)
		  Constructor
		  
		  dim rx as new RegEx
		  rx.SearchPattern = kPatternURL
		  
		  dim match as RegExMatch = rx.Search( url )
		  if match is nil then
		    raise new UnsupportedFormatException
		  end if
		  
		  dim parts( 4 ) as string
		  for i as integer = 1 to match.SubExpressionCount - 1
		    parts( i - 1 ) = match.SubExpressionString( i )
		  next i
		  
		  if parts( 0 ) <> "" then
		    Protocol = parts( 0 )
		  end if
		  Host = parts( 1 )
		  if parts( 2 ) <> "" then
		    Port = parts( 2 ).Val
		  end if
		  Resource = parts( 3 )
		  
		  //
		  // Params
		  //
		  dim paramString as string = parts( 4 ).Trim
		  if paramString <> "" then
		    dim params() as string = paramString.Split( "&" )
		    for each param as string in params
		      param = param.Trim
		      if param <> "" then
		        dim paramParts() as string = param.Split( "=" )
		        dim key as string = paramParts( 0 )
		        dim value as string = paramString.Mid( key.Len + 2 )
		        value = DecodeURLComponent( value )
		        
		        Parameters.Value( key ) = value
		      end if
		    next
		  end if
		End Sub
	#tag EndMethod


	#tag Property, Flags = &h0
		Host As String
	#tag EndProperty

	#tag Property, Flags = &h21
		Attributes( hidden ) Private mParameters As Dictionary
	#tag EndProperty

	#tag ComputedProperty, Flags = &h0
		#tag Getter
			Get
			  if mParameters is nil then
			    mParameters = new Dictionary
			  end if
			  
			  return mParameters
			End Get
		#tag EndGetter
		#tag Setter
			Set
			  mParameters = value
			  
			End Set
		#tag EndSetter
		Parameters As Dictionary
	#tag EndComputedProperty

	#tag ComputedProperty, Flags = &h0
		#tag Getter
			Get
			  dim params as Dictionary = Parameters
			  
			  if params.Count = 0 then
			    return ""
			  end if
			  
			  dim keys() as variant = params.Keys
			  dim values() as variant = params.Values
			  
			  dim parts() as string
			  for i as integer = 0 to keys.Ubound
			    dim k as variant = keys( i )
			    dim v as variant = values( i )
			    
			    parts.Append k.StringValue
			    parts.Append "="
			    parts.Append EncodeURLComponent( v.StringValue )
			  next i
			  
			  return join( parts, "&" )
			  
			End Get
		#tag EndGetter
		ParametersToString As String
	#tag EndComputedProperty

	#tag Property, Flags = &h0
		Port As Integer = -1
	#tag EndProperty

	#tag Property, Flags = &h0
		Protocol As String = "http"
	#tag EndProperty

	#tag Property, Flags = &h0
		Resource As String
	#tag EndProperty

	#tag ComputedProperty, Flags = &h0
		#tag Getter
			Get
			  dim parts() as string
			  
			  if Protocol.Trim = "" then
			    parts.Append "http"
			  else
			    parts.Append Protocol.Trim
			  end if
			  
			  parts.Append "://"
			  parts.Append Host.Trim
			  
			  if Port > 0 then
			    parts.Append ":"
			    parts.Append str( Port )
			  end if
			  
			  parts.Append "/"
			  parts.Append Resource.Trim
			  
			  dim params as string = ParametersToString
			  if params <> "" then
			    parts.Append "?"
			    parts.Append params
			  end if
			  
			  return join( parts, "" )
			  
			End Get
		#tag EndGetter
		ToString As String
	#tag EndComputedProperty


	#tag Constant, Name = kPatternURL, Type = String, Dynamic = False, Default = \"(\?x)\n\n^\n# Prefix\n(\?:([a-z]{2\x2C})://)\?\n\n# Host\n([^/:\\s]*)\n\n# Port\n(\?::(\\d+))\?\n\n# Trailing slash\n/\?\n\n# Resource\n([^\?\\s*]*)\n\n# Params\n(\?:\\\?(.+))\?\n", Scope = Private
	#tag EndConstant


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
