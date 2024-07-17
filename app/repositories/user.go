package repositories

import (
	"test/models"

	"gorm.io/gorm"
)

type UserRepository interface {
	Create(user *models.User) error
	List() ([]*models.User, error)
	GetById(ID uint) (*models.User, error)
	DeleteUser(userID int) error
}

type UserRepositoryImpl struct {
	DB *gorm.DB
}

func NewUserRepository(d *gorm.DB) UserRepository {
	return &UserRepositoryImpl{d}
}

func (r UserRepositoryImpl) Create(user *models.User) error {
	return r.DB.Save(user).Error
}

func (r UserRepositoryImpl) List() ([]*models.User, error) {
	var users []*models.User
	if err := r.DB.Find(&users).Error; err != nil {
		return nil, err
	}

	return users, nil
}

func (r UserRepositoryImpl) GetById(ID uint) (*models.User, error) {
	var user *models.User
	if err := r.DB.Find(&user).Where("id = ?", ID).Error; err != nil {
		return nil, err
	}

	return user, nil
}

func (r UserRepositoryImpl) DeleteUser(userID int) error {
	var u models.User
	return r.DB.Delete(&u, userID).Error
}
