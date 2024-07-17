package handlers

import (
	"net/http"
	"test/api"
	"test/models"
	"test/repositories"

	"github.com/go-chi/render"
	"github.com/go-playground/validator"
)

type UserHandler struct {
	r repositories.UserRepository
	v *validator.Validate
}

func NewUserHandler(r repositories.UserRepository) *UserHandler {
	return &UserHandler{r, validator.New()}
}

func (h *UserHandler) GetUsers(w http.ResponseWriter, r *http.Request) {
	us, err := h.r.List()
	if err != nil {
		error(w, r, http.StatusInternalServerError, err.Error())
		return
	}

	resp := []*api.UserResponse{}
	for _, v := range us {
		resp = append(resp, &api.UserResponse{
			Id:   int(v.ID),
			Name: v.Name,
		})
	}

	success(w, r, resp)
}

func (h *UserHandler) CreateUser(w http.ResponseWriter, r *http.Request) {
	var rb api.UserInput
	if err := render.DecodeJSON(r.Body, &rb); err != nil {
		error(w, r, http.StatusBadRequest, err.Error())
		return
	}

	if err := h.v.Struct(rb); err != nil {
		error(w, r, http.StatusBadRequest, err.Error())
		return
	}

	u := &models.User{Name: rb.Name}
	if err := h.r.Create(u); err != nil {
		error(w, r, http.StatusInternalServerError, err.Error())
		return
	}

	success(w, r, api.UserResponse{
		Id:   int(u.ID),
		Name: u.Name,
	})
}

func (h *UserHandler) GetUser(w http.ResponseWriter, r *http.Request, userId api.UserId) {
	u, err := h.r.GetById(uint(userId))
	if err != nil {
		error(w, r, http.StatusInternalServerError, err.Error())
		return
	}
	success(w, r, api.UserResponse{
		Id:   int(u.ID),
		Name: u.Name,
	})
}

func (h *UserHandler) DeleteUser(w http.ResponseWriter, r *http.Request, userID api.UserId) {
	if err := h.r.DeleteUser(userID); err != nil {
		error(w, r, http.StatusInternalServerError, err.Error())
		return
	}
	success(w, r, map[string]string{"message": "success"})
}

func success(w http.ResponseWriter, r *http.Request, d interface{}) {
	render.Status(r, http.StatusOK)
	render.JSON(w, r, d)
}

func error(w http.ResponseWriter, r *http.Request, status int, d string) {
	render.Status(r, status)
	render.JSON(w, r, map[string]string{"message": d})
}
