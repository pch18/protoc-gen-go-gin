
var marshaler = protojson.MarshalOptions{
	UseProtoNames:   true,
	EmitUnpopulated: true,
	// UseEnumNumbers:  true,
}
var unmarshaler = protojson.UnmarshalOptions{
	AllowPartial:false,
	DiscardUnknown:true,
}

type {{ $.InterfaceName }} interface {
{{range .MethodSet}}
	{{.Name}}(ctx *gin.Context, in *{{.Request}}) (*{{.Reply}}, error)
{{end}}
}
func Register{{ $.InterfaceName }}(r gin.IRouter, srv {{ $.InterfaceName }}) {
	s := {{.Name}}{
		server: srv,
		router:     r,
		resp: default{{$.Name}}Resp{},
	}
	s.RegisterService()
}

type {{$.Name}} struct{
	server {{ $.InterfaceName }}
	router gin.IRouter
	resp  interface {
		Error(ctx *gin.Context, err error)
		ParamsError (ctx *gin.Context, err error)
		Success(ctx *gin.Context, data interface{})
	}
}

// Resp 返回值
type default{{$.Name}}Resp struct {}

func (resp default{{$.Name}}Resp) response(ctx *gin.Context, status, code int, msg string, data interface{}) {
	ctx.JSON(status, map[string]interface{}{
		"code": code, 
		"msg": msg,
		"data": data,
	})
}

// Error 返回错误信息
func (resp default{{$.Name}}Resp) Error(ctx *gin.Context, err error) {
	code := -1
	status := 500
	msg := "InternalError"
	
	if err == nil {
		msg += ", err is nil"
		resp.response(ctx, status, code, msg, nil)
		return
	}

	type iCode interface{
		HTTPCode() int
		Message() string
		Code() int
	}

	var c iCode
	if errors.As(err, &c) {
		status = c.HTTPCode()
		code = c.Code()
		msg = c.Message()
	}

	_ = ctx.Error(err)

	resp.response(ctx, status, code, msg, nil)
}

// ParamsError 参数错误
func (resp default{{$.Name}}Resp) ParamsError (ctx *gin.Context, err error) {
	_ = ctx.Error(err)
	resp.response(ctx, 400, 400, "ParamsError", nil)
}

// Success 返回成功信息
func (resp default{{$.Name}}Resp) Success(ctx *gin.Context, data interface{}) {
	resp.response(ctx, 200, 0, "Success", data)
}


{{range .Methods}}
func (s *{{$.Name}}) {{ .HandlerName }} (ctx *gin.Context) {
	var in {{.Request}}

	reqRaw,err := io.ReadAll(ctx.Request.Body)
	if err != nil {
		s.resp.ParamsError(ctx, err)
		return
	}
	err = unmarshaler.Unmarshal(reqRaw, &in)
	if err != nil {
		s.resp.ParamsError(ctx, err)
		return
	}
	
	out, err := s.server.({{ $.InterfaceName }}).{{.Name}}(ctx, &in)
	if err != nil {
		s.resp.Error(ctx, err)
		return
	}

	var jsonRaw json.RawMessage
	jsonRaw, err = marshaler.Marshal(out)
	if err != nil {
		s.resp.Error(ctx, err)
		return
	}
	s.resp.Success(ctx, jsonRaw)
}
{{end}}

func (s *{{$.Name}}) RegisterService() {
{{range .Methods}}
		s.router.Handle("{{.Method}}", "{{.Path}}", s.{{ .HandlerName }})
{{end}}
}