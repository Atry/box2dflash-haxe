﻿/*
* Copyright (c) 2006-2007 Erin Catto http://www.gphysics.com
*
* This software is provided 'as-is', without any express or implied
* warranty.  In no event will the authors be held liable for any damages
* arising from the use of this software.
* Permission is granted to anyone to use this software for any purpose,
* including commercial applications, and to alter it and redistribute it
* freely, subject to the following restrictions:
* 1. The origin of this software must not be misrepresented; you must not
* claim that you wrote the original software. If you use this software
* in a product, an acknowledgment in the product documentation would be
* appreciated but is not required.
* 2. Altered source versions must be plainly marked as such, and must not be
* misrepresented as being the original software.
* 3. This notice may not be removed or altered from any source distribution.
*/

package Box2D.Dynamics{


import Box2D.Collision.IBroadPhase;
import Box2D.Dynamics.*;
import Box2D.Dynamics.Controllers.b2ControllerEdge;
import Box2D.Dynamics.Joints.*;
import Box2D.Dynamics.Contacts.*;
import Box2D.Collision.Shapes.*;
import Box2D.Common.Math.*;
import Box2D.Common.*;

import Box2D.Common.b2internal;
use namespace b2internal;



/**
* A rigid body.
*/
public class b2Body
{

	private function connectEdges(s1: b2EdgeShape, s2: b2EdgeShape, angle1: Number): Number
	{
		var angle2: Number = Math.atan2(s2.GetDirectionVector().y, s2.GetDirectionVector().x);
		var coreOffset: Number = Math.tan((angle2 - angle1) * 0.5);
		var core: b2Vec2 = b2Math.MulFV(coreOffset, s2.GetDirectionVector());
		core = b2Math.SubtractVV(core, s2.GetNormalVector());
		core = b2Math.MulFV(b2Settings.b2_toiSlop, core);
		core = b2Math.AddVV(core, s2.GetVertex1());
		var cornerDir: b2Vec2 = b2Math.AddVV(s1.GetDirectionVector(), s2.GetDirectionVector());
		cornerDir.Normalize();
		var convex: Boolean = b2Math.b2Dot(s1.GetDirectionVector(), s2.GetNormalVector()) > 0.0;
		s1.SetNextEdge(s2, core, cornerDir, convex);
		s2.SetPrevEdge(s1, core, cornerDir, convex);
		return angle2;
	}
	
	/**
	 * Creates a fixture and attach it to this body.
	 * @param fixtureDef the fixture definition.
	 * @warning This function is locked during callbacks.
	 */
	public function CreateFixture(def:b2FixtureDef) : b2Fixture{
		//b2Settings.b2Assert(m_world.IsLocked() == false);
		if (m_world.IsLocked() == true)
		{
			return null;
		}
		
		// TODO: Decide on a better place to initialize edgeShapes. (b2Shape::Create() can't
		//       return more than one shape to add to parent body... maybe it should add
		//       shapes directly to the body instead of returning them?)
		/*
		if (def.type == b2Shape.e_edgeShape) {
			var edgeDef: b2EdgeChainDef = def as b2EdgeChainDef;
			var v1: b2Vec2;
			var v2: b2Vec2;
			var i: int;
			
			if (edgeDef.isALoop) {
				v1 = edgeDef.vertices[edgeDef.vertexCount-1];
				i = 0;
			} else {
				v1 = edgeDef.vertices[0];
				i = 1;
			}
			
			var s0: b2EdgeShape = null;
			var s1: b2EdgeShape = null;
			var s2: b2EdgeShape = null;
			var angle: Number = 0.0;
			for (; i < edgeDef.vertexCount; i++) {
				v2 = edgeDef.vertices[i];
				
				//void* mem = m_world->m_blockAllocator.Allocate(sizeof(b2EdgeShape));
				s2 = new b2EdgeShape(v1, v2, def);
				s2.m_next = m_shapeList;
				m_shapeList = s2;
				++m_shapeCount;
				s2.m_body = this;
				s2.CreateProxy(m_world.m_broadPhase, m_xf);
				s2.UpdateSweepRadius(m_sweep.localCenter);
				
				if (s1 == null) {
					s0 = s2;
					angle = Math.atan2(s2.GetDirectionVector().y, s2.GetDirectionVector().x);
				} else {
					angle = connectEdges(s1, s2, angle);
				}
				s1 = s2;
				v1 = v2;
			}
			if (edgeDef.isALoop) connectEdges(s1, s0, angle);
			return s0;
		}*/
		
		var broadPhase:IBroadPhase = m_world.m_contactManager.m_broadPhase;
		
		var fixture:b2Fixture = new b2Fixture();
		fixture.Create(broadPhase, this, m_xf, def);
		
		fixture.m_next = m_fixtureList;
		m_fixtureList = fixture;
		++m_fixtureCount;
		
		fixture.m_body = this;
		
		// Let the world know we have a new fixture
		m_world.m_flags |= b2World.e_newFixture;
		
		return fixture;
	}

	/// Creates a fixture from a shape and attach it to this body.
	/// This is a convenience function. Use b2FixtureDef if you need to set parameters
	/// like friction, restitution, user data, or filtering.
	/// @param shape the shape to be cloned.
	/// @param density the shape density (set to zero for static bodies).
	/// @warning This function is locked during callbacks.
	public function CreateFixture2(shape:b2Shape, density:Number=0.0):b2Fixture
	{
		var def:b2FixtureDef = new b2FixtureDef();
		def.shape = shape;
		def.density = density;
		
		return CreateFixture(def);
	}
	
	/// Destroy a fixture. This removes the fixture from the broad-phase and
	/// therefore destroys any contacts associated with this fixture. All fixtures
	/// attached to a body are implicitly destroyed when the body is destroyed.
	/// @param fixture the fixture to be removed.
	/// @warning This function is locked during callbacks.
	public function DestroyFixture(fixture:b2Fixture) : void{
		//b2Settings.b2Assert(m_world.IsLocked() == false);
		if (m_world.IsLocked() == true)
		{
			return;
		}
		
		//b2Settings.b2Assert(m_fixtureCount > 0);
		//b2Fixture** node = &m_fixtureList;
		var node:b2Fixture = m_fixtureList;
		var ppF:b2Fixture = null; // Fix pointer-pointer stuff
		var found:Boolean = false;
		while (node != null)
		{
			if (node == fixture)
			{
				if (ppF)
					ppF.m_next = fixture.m_next;
				else
					m_fixtureList = fixture.m_next;
				//node = fixture.m_next;
				found = true;
				break;
			}
			
			ppF = node;
			node = node.m_next;
		}
		
		// You tried to remove a shape that is not attached to this body.
		//b2Settings.b2Assert(found);
		
		// Destroy any contacts associated with the fixture.
		var edge:b2ContactEdge = m_contactList;
		while (edge)
		{
			var c:b2Contact = edge.contact;
			edge = edge.next;
			
			var fixtureA:b2Fixture = c.GetFixtureA();
			var fixtureB:b2Fixture = c.GetFixtureB();
			if (fixture == fixtureA || fixture == fixtureB)
			{
				// This destros the contact and removes it from
				// this body's contact list
				m_world.m_contactManager.Destroy(c);
			}
		}
		
		var broadPhase:IBroadPhase = m_world.m_contactManager.m_broadPhase;
		
		fixture.Destroy( broadPhase );
		fixture.m_body = null;
		fixture.m_next = null;
		
		--m_fixtureCount;
	}

	/**
	* Set the mass properties. Note that this changes the center of mass position.
	* If you are not sure how to compute mass properties, use SetMassFromShapes.
	* The inertia tensor is assumed to be relative to the center of mass.
	* @param massData the mass properties.
	*/
	public function SetMassData(massData:b2MassData) : void{
		var fixture:b2Fixture;
		
		//b2Settings.b2Assert(m_world.IsLocked() == false);
		if (m_world.IsLocked() == true)
		{
			return;
		}
		
		m_invMass = 0.0;
		m_I = 0.0;
		m_invI = 0.0;
		
		m_mass = massData.mass;
		
		if (m_mass > 0.0)
		{
			m_invMass = 1.0 / m_mass;
		}
		
		m_I = massData.I;
		
		if (m_I > 0.0 && (m_flags & b2Body.e_fixedRotationFlag) == 0)
		{
			m_invI = 1.0 / m_I;
		}
		
		// Move center of mass.
		m_sweep.localCenter.SetV(massData.center);
		//m_sweep.c0 = m_sweep.c = b2Mul(m_xf, m_sweep.localCenter);
		//b2MulMV(m_xf.R, m_sweep.localCenter);
		var tMat:b2Mat22 = m_xf.R;
		var tVec:b2Vec2 = m_sweep.localCenter;
		// (tMat.col1.x * tVec.x + tMat.col2.x * tVec.y)
		m_sweep.c.x = (tMat.col1.x * tVec.x + tMat.col2.x * tVec.y);
		// (tMat.col1.y * tVec.x + tMat.col2.y * tVec.y)
		m_sweep.c.y = (tMat.col1.y * tVec.x + tMat.col2.y * tVec.y);
		//return T.position + b2Mul(T.R, v);
		m_sweep.c.x += m_xf.position.x;
		m_sweep.c.y += m_xf.position.y;
		//m_sweep.c0 = m_sweep.c
		m_sweep.c0.SetV(m_sweep.c);
		
		var oldType:int = m_type;
		if (m_invMass == 0.0 && m_invI == 0.0)
		{
			m_type = e_staticType;
		}
		else
		{
			m_type = e_dynamicType;
		}
	
		// If the body type changed, we need to refilter the broad-phase proxies.
		if (oldType != m_type)
		{
			for (var ce:b2ContactEdge = m_contactList; ce; ce = ce.next)
			{
				ce.contact.FlagForFiltering();
			}
		}
	}


	static private var s_massData:b2MassData = new b2MassData();
	/**
	* Compute the mass properties from the attached shapes. You typically call this
	* after adding all the shapes. If you add or remove shapes later, you may want
	* to call this again. Note that this changes the center of mass position.
	*/
	public function SetMassFromShapes() : void{
		
		var f:b2Fixture;
		
		//b2Settings.b2Assert(m_world.IsLocked() == false);
		if (m_world.IsLocked() == true)
		{
			return;
		}
		
		// Compute mass data from shapes. Each shape has its own density.
		m_mass = 0.0;
		m_invMass = 0.0;
		m_I = 0.0;
		m_invI = 0.0;
		
		//b2Vec2 center = b2Vec2_zero;
		var centerX:Number = 0.0;
		var centerY:Number = 0.0;
		var massData:b2MassData = s_massData;
		for (f = m_fixtureList; f; f = f.m_next)
		{
			f.ComputeMass(massData);
			m_mass += massData.mass;
			//center += massData.mass * massData.center;
			centerX += massData.mass * massData.center.x;
			centerY += massData.mass * massData.center.y;
			m_I += massData.I;
		}
		
		// Compute center of mass, and shift the origin to the COM.
		if (m_mass > 0.0)
		{
			m_invMass = 1.0 / m_mass;
			centerX *= m_invMass;
			centerY *= m_invMass;
		}
		
		if (m_I > 0.0 && (m_flags & e_fixedRotationFlag) == 0)
		{
			// Center the inertia about the center of mass.
			//m_I -= m_mass * b2Dot(center, center);
			m_I -= m_mass * (centerX * centerX + centerY * centerY);
			//b2Settings.b2Assert(m_I > 0.0);
			m_invI = 1.0 / m_I;
		}
		else
		{
			m_I = 0.0;
			m_invI = 0.0;
		}
		
		// Move center of mass.
		m_sweep.localCenter.Set(centerX, centerY);
		//m_sweep.c0 = m_sweep.c = b2Mul(m_xf, m_sweep.localCenter);
		//b2MulMV(m_xf.R, m_sweep.localCenter);
		var tMat:b2Mat22 = m_xf.R;
		var tVec:b2Vec2 = m_sweep.localCenter;
		// (tMat.col1.x * tVec.x + tMat.col2.x * tVec.y)
		m_sweep.c.x = (tMat.col1.x * tVec.x + tMat.col2.x * tVec.y);
		// (tMat.col1.y * tVec.x + tMat.col2.y * tVec.y)
		m_sweep.c.y = (tMat.col1.y * tVec.x + tMat.col2.y * tVec.y);
		//return T.position + b2Mul(T.R, v);
		m_sweep.c.x += m_xf.position.x;
		m_sweep.c.y += m_xf.position.y;
		//m_sweep.c0 = m_sweep.c
		m_sweep.c0.SetV(m_sweep.c);
		
		var oldType:int = m_type;
		if (m_invMass == 0.0 && m_invI == 0.0)
		{
			m_type = e_staticType;
		}
		else
		{
			m_type = e_dynamicType;
		}
		
		// If the body type changed, we need to refilter the broad-phase proxies.
		if (oldType != m_type)
		{
			for (var ce:b2ContactEdge = m_contactList; ce; ce = ce.next)
			{
				ce.contact.FlagForFiltering();
			}
		}
	}

	/**
	* Set the position of the body's origin and rotation (radians).
	* This breaks any contacts and wakes the other bodies.
	* @param position the new world position of the body's origin (not necessarily
	* the center of mass).
	* @param angle the new world rotation angle of the body in radians.
	*/
	public function SetPositionAndAngle(position:b2Vec2, angle:Number) : void{
		
		var f:b2Fixture;
		
		//b2Settings.b2Assert(m_world.IsLocked() == false);
		if (m_world.IsLocked() == true)
		{
			return;
		}
		
		m_xf.R.Set(angle);
		m_xf.position.SetV(position);
		
		//m_sweep.c0 = m_sweep.c = b2Mul(m_xf, m_sweep.localCenter);
		//b2MulMV(m_xf.R, m_sweep.localCenter);
		var tMat:b2Mat22 = m_xf.R;
		var tVec:b2Vec2 = m_sweep.localCenter;
		// (tMat.col1.x * tVec.x + tMat.col2.x * tVec.y)
		m_sweep.c.x = (tMat.col1.x * tVec.x + tMat.col2.x * tVec.y);
		// (tMat.col1.y * tVec.x + tMat.col2.y * tVec.y)
		m_sweep.c.y = (tMat.col1.y * tVec.x + tMat.col2.y * tVec.y);
		//return T.position + b2Mul(T.R, v);
		m_sweep.c.x += m_xf.position.x;
		m_sweep.c.y += m_xf.position.y;
		//m_sweep.c0 = m_sweep.c
		m_sweep.c0.SetV(m_sweep.c);
		
		m_sweep.a0 = m_sweep.a = angle;
		
		var broadPhase:IBroadPhase = m_world.m_contactManager.m_broadPhase;
		for (f = m_fixtureList; f; f = f.m_next)
		{
			f.Synchronize(broadPhase, m_xf, m_xf);
		}
		m_world.m_contactManager.FindNewContacts();
	}
	
	/**
	 * Set the position of the body's origin and rotation (radians).
	 * This breaks any contacts and wakes the other bodies.
	 * Note this is less efficient than the other overload - you should use that
	 * if the angle is available.
	 * @param xf the transform of position and angle to set the bdoy to.
	 */
	public function SetTransform(xf:b2Transform):void
	{
		SetPositionAndAngle(xf.position, xf.GetAngle());
	}

	/**
	* Get the body transform for the body's origin.
	* @return the world transform of the body's origin.
	*/
	public function GetTransform() : b2Transform{
		return m_xf;
	}

	/**
	* Get the world body origin position.
	* @return the world position of the body's origin.
	*/
	public function GetPosition() : b2Vec2{
		return m_xf.position;
	}
	
	/**
	 * Setthe world body origin position.
	 * @param position the new position of the body
	 */
	public function SetPosition(position:b2Vec2):void
	{
		SetPositionAndAngle(position, GetAngle());
	}

	/**
	* Get the angle in radians.
	* @return the current world rotation angle in radians.
	*/
	public function GetAngle() : Number{
		return m_sweep.a;
	}
	
	/**
	 * Set the world body angle
	 * @param angle the new angle of the body.
	 */
	public function SetAngle(angle:Number) : void
	{
		SetPositionAndAngle(GetPosition(), angle);
	}
	

	/**
	* Get the world position of the center of mass.
	*/
	public function GetWorldCenter() : b2Vec2{
		return m_sweep.c;
	}

	/**
	* Get the local position of the center of mass.
	*/
	public function GetLocalCenter() : b2Vec2{
		return m_sweep.localCenter;
	}

	/**
	* Set the linear velocity of the center of mass.
	* @param v the new linear velocity of the center of mass.
	*/
	public function SetLinearVelocity(v:b2Vec2) : void{
		m_linearVelocity.SetV(v);
	}

	/**
	* Get the linear velocity of the center of mass.
	* @return the linear velocity of the center of mass.
	*/
	public function GetLinearVelocity() : b2Vec2{
		return m_linearVelocity;
	}

	/**
	* Set the angular velocity.
	* @param omega the new angular velocity in radians/second.
	*/
	public function SetAngularVelocity(omega:Number) : void{
		m_angularVelocity = omega;
	}

	/**
	* Get the angular velocity.
	* @return the angular velocity in radians/second.
	*/
	public function GetAngularVelocity() : Number{
		return m_angularVelocity;
	}
	
	public function GetDefinition() : b2BodyDef
	{
		var bd:b2BodyDef = new b2BodyDef();
		bd.allowSleep = (m_flags & e_allowSleepFlag) > 0;
		bd.angle = GetAngle();
		bd.angularDamping = m_angularDamping;
		bd.angularVelocity = m_angularVelocity;
		bd.fixedRotation = (m_flags & e_fixedRotationFlag) > 0;
		bd.isBullet = (m_flags & e_bulletFlag) > 0;
		bd.isSleeping = IsSleeping();
		bd.linearDamping = m_linearDamping;
		bd.linearVelocity.SetV(GetLinearVelocity());
		bd.massData.mass = GetMass();
		bd.massData.center = GetLocalCenter();
		bd.massData.I = GetInertia();
		bd.position = GetPosition();
		bd.userData = GetUserData();
		return bd;
	}

	/**
	* Apply a force at a world point. If the force is not
	* applied at the center of mass, it will generate a torque and
	* affect the angular velocity. This wakes up the body.
	* @param force the world force vector, usually in Newtons (N).
	* @param point the world position of the point of application.
	*/
	public function ApplyForce(force:b2Vec2, point:b2Vec2) : void{
		if (IsSleeping())
		{
			WakeUp();
		}
		//m_force += force;
		m_force.x += force.x;
		m_force.y += force.y;
		//m_torque += b2Cross(point - m_sweep.c, force);
		m_torque += ((point.x - m_sweep.c.x) * force.y - (point.y - m_sweep.c.y) * force.x);
	}

	/**
	* Apply a torque. This affects the angular velocity
	* without affecting the linear velocity of the center of mass.
	* This wakes up the body.
	* @param torque about the z-axis (out of the screen), usually in N-m.
	*/
	public function ApplyTorque(torque:Number) : void{
		if (IsSleeping())
		{
			WakeUp();
		}
		m_torque += torque;
	}

	/**
	* Apply an impulse at a point. This immediately modifies the velocity.
	* It also modifies the angular velocity if the point of application
	* is not at the center of mass. This wakes up the body.
	* @param impulse the world impulse vector, usually in N-seconds or kg-m/s.
	* @param point the world position of the point of application.
	*/
	public function ApplyImpulse(impulse:b2Vec2, point:b2Vec2) : void{
		if (IsSleeping())
		{
			WakeUp();
		}
		//m_linearVelocity += m_invMass * impulse;
		m_linearVelocity.x += m_invMass * impulse.x;
		m_linearVelocity.y += m_invMass * impulse.y;
		//m_angularVelocity += m_invI * b2Cross(point - m_sweep.c, impulse);
		m_angularVelocity += m_invI * ((point.x - m_sweep.c.x) * impulse.y - (point.y - m_sweep.c.y) * impulse.x);
	}
	
	/**
	 * Splits a body into two, preserving dynamic properties
	 * @param	callback Called once per fixture, return true to move this fixture to the new body
	 * <code>function Callback(fixture:b2Fixture):Boolean</code>
	 * @return The newly created bodies
	 */
	public function Split(callback:Function):b2Body
	{
		var linearVelocity:b2Vec2 = GetLinearVelocity();
		var angularVelocity:Number = GetAngularVelocity();
		var center:b2Vec2 = GetWorldCenter();
		var body1:b2Body = this;
		var body2:b2Body = m_world.CreateBody(GetDefinition());
		
		var prev:b2Fixture;
		for (var f:b2Fixture = body1.m_fixtureList; f; )
		{
			if (callback(f))
			{
				var next:b2Fixture = f.m_next;
				// Remove fixture
				if (prev)
				{
					prev.m_next = next;
				}else {
					body1.m_fixtureList = next;
				}
				body1.m_fixtureCount--;
				
				// Add fixture
				f.m_next = body2.m_fixtureList;
				body2.m_fixtureList = f;
				body2.m_fixtureCount++;
				
				f.m_body = body2;
				
				f = next;
			}else {
				prev = f;
				f = f.m_next
			}
		}
		
		body1.SetMassFromShapes();
		body2.SetMassFromShapes();
		
		// Compute consistent velocites for new bodies based on cached velocity
		var center1:b2Vec2 = body1.GetWorldCenter();
		var center2:b2Vec2 = body2.GetWorldCenter();
		
		var velocity1:b2Vec2 = b2Math.AddVV(linearVelocity, 
			b2Math.b2CrossFV(angularVelocity,
				b2Math.SubtractVV(center1, center)));
				
		var velocity2:b2Vec2 = b2Math.AddVV(linearVelocity, 
			b2Math.b2CrossFV(angularVelocity,
				b2Math.SubtractVV(center2, center)));
				
		body1.SetLinearVelocity(velocity1);
		body2.SetLinearVelocity(velocity2);
		body1.SetAngularVelocity(angularVelocity);
		body2.SetAngularVelocity(angularVelocity);
		
		body1.SynchronizeFixtures();
		body2.SynchronizeFixtures();
		
		return body2;
	}

	/**
	* Get the total mass of the body.
	* @return the mass, usually in kilograms (kg).
	*/
	public function GetMass() : Number{
		return m_mass;
	}

	/**
	* Get the central rotational inertia of the body.
	* @return the rotational inertia, usually in kg-m^2.
	*/
	public function GetInertia() : Number{
		return m_I;
	}
	
	/** 
	 * Get the mass data of the body.
	 */
	public function GetMassData():b2MassData
	{
		var massData:b2MassData = new b2MassData();
		massData.mass = m_mass;
		massData.I = m_I;
		massData.center.SetV(m_sweep.localCenter);
		return massData;
	}
	  
	/**
	* Get the world coordinates of a point given the local coordinates.
	* @param localPoint a point on the body measured relative the the body's origin.
	* @return the same point expressed in world coordinates.
	*/
	public function GetWorldPoint(localPoint:b2Vec2) : b2Vec2{
		//return b2Math.b2MulX(m_xf, localPoint);
		var A:b2Mat22 = m_xf.R;
		var u:b2Vec2 = new b2Vec2(A.col1.x * localPoint.x + A.col2.x * localPoint.y, 
								  A.col1.y * localPoint.x + A.col2.y * localPoint.y);
		u.x += m_xf.position.x;
		u.y += m_xf.position.y;
		return u;
	}

	/**
	* Get the world coordinates of a vector given the local coordinates.
	* @param localVector a vector fixed in the body.
	* @return the same vector expressed in world coordinates.
	*/
	public function GetWorldVector(localVector:b2Vec2) : b2Vec2{
		return b2Math.b2MulMV(m_xf.R, localVector);
	}

	/**
	* Gets a local point relative to the body's origin given a world point.
	* @param a point in world coordinates.
	* @return the corresponding local point relative to the body's origin.
	*/
	public function GetLocalPoint(worldPoint:b2Vec2) : b2Vec2{
		return b2Math.b2MulXT(m_xf, worldPoint);
	}

	/**
	* Gets a local vector given a world vector.
	* @param a vector in world coordinates.
	* @return the corresponding local vector.
	*/
	public function GetLocalVector(worldVector:b2Vec2) : b2Vec2{
		return b2Math.b2MulTMV(m_xf.R, worldVector);
	}
	
	/**
	* Get the world linear velocity of a world point attached to this body.
	* @param a point in world coordinates.
	* @return the world velocity of a point.
	*/
	public function GetLinearVelocityFromWorldPoint(worldPoint:b2Vec2) : b2Vec2
	{
		//return          m_linearVelocity   + b2Cross(m_angularVelocity,   worldPoint   - m_sweep.c);
		return new b2Vec2(m_linearVelocity.x -         m_angularVelocity * (worldPoint.y - m_sweep.c.y), 
		                  m_linearVelocity.y +         m_angularVelocity * (worldPoint.x - m_sweep.c.x));
	}
	
	/**
	* Get the world velocity of a local point.
	* @param a point in local coordinates.
	* @return the world velocity of a point.
	*/
	public function GetLinearVelocityFromLocalPoint(localPoint:b2Vec2) : b2Vec2
	{
		//return GetLinearVelocityFromWorldPoint(GetWorldPoint(localPoint));
		var A:b2Mat22 = m_xf.R;
		var worldPoint:b2Vec2 = new b2Vec2(A.col1.x * localPoint.x + A.col2.x * localPoint.y, 
		                                   A.col1.y * localPoint.x + A.col2.y * localPoint.y);
		worldPoint.x += m_xf.position.x;
		worldPoint.y += m_xf.position.y;
		return new b2Vec2(m_linearVelocity.x -         m_angularVelocity * (worldPoint.y - m_sweep.c.y), 
		                  m_linearVelocity.y +         m_angularVelocity * (worldPoint.x - m_sweep.c.x));
	}
	
	/**
	* Get the linear damping of the body.
	*/
	public function GetLinearDamping():Number
	{
		return m_linearDamping;
	}
	
	/**
	* Set the linear damping of the body.
	*/
	public function SetLinearDamping(linearDamping:Number):void
	{
		m_linearDamping = linearDamping;
	}
	
	/**
	* Get the angular damping of the body
	*/
	public function GetAngularDamping():Number
	{
		return m_angularDamping;
	}
	
	/**
	* Set the angular damping of the body.
	*/
	public function SetAngularDamping(angularDamping:Number):void
	{
		m_angularDamping = angularDamping;
	}
	
	/**
	* Is this body treated like a bullet for continuous collision detection?
	*/
	public function IsBullet() : Boolean{
		return (m_flags & e_bulletFlag) == e_bulletFlag;
	}

	/**
	* Should this body be treated like a bullet for continuous collision detection?
	*/
	public function SetBullet(flag:Boolean) : void{
		if (flag)
		{
			m_flags |= e_bulletFlag;
		}
		else
		{
			m_flags &= ~e_bulletFlag;
		}
	}

	
	/**
	* Is this body prevented from rotating?
	*/
	public function IsFixedRotation():Boolean
	{
		return (m_flags & e_fixedRotationFlag)==e_fixedRotationFlag;
	}
	/**
	* Set if this body is prevented from rotating.
	*/
	public function SetFixedRotation(fixed:Boolean):void
	{
		if(fixed)
		{
			m_angularVelocity = 0.0;
			m_invI = 0.0;
			m_flags |= e_fixedRotationFlag;
		}
		else
		{
			if(m_I > 0.0)
			{
				//Recover m_invI from m_I
				m_invI = 1.0/m_I
				m_flags &= e_fixedRotationFlag;
			}
			//TODO: Else what?
		}
	}
	
	
	
	/**
	* Is this body static (immovable)?
	*/
	public function IsStatic() : Boolean{
		return m_type == e_staticType;
	}
	
	/**
	* Make this body static (immovable).
	* Use SetMass and SetMassFromShapes to make bodies dynamic
	*/
	public function SetStatic():void
	{
		if(m_type == e_staticType)
			return
			
		m_mass = 0.0;
		m_invMass = 0.0;
		m_I = 0.0;
		m_invI = 0.0;
		m_type = e_staticType;
		
		for (var ce:b2ContactEdge = m_contactList; ce; ce = ce.next)
		{
			ce.contact.FlagForFiltering();
		}
	}

	/**
	* Is this body dynamic (movable)?
	*/
	public function IsDynamic() :Boolean{
		return m_type == e_dynamicType;
	}

	/**
	* Is this body sleeping (not simulating).
	*/
	public function IsSleeping() : Boolean{
		return (m_flags & e_sleepFlag) == e_sleepFlag;
	}
	
	/**
	* Is this body allowed to sleep?
	*/
	public function IsAllowSleeping():Boolean
	{
		return(m_flags & e_allowSleepFlag) == e_allowSleepFlag;
	}
	
	/**
	* You can disable sleeping on this body.
	*/
	public function AllowSleeping(flag:Boolean) : void{
		if (flag)
		{
			m_flags |= e_allowSleepFlag;
		}
		else
		{
			m_flags &= ~e_allowSleepFlag;
			WakeUp();
		}
	}

	/**
	* Wake up this body so it will begin simulating.
	*/
	public function WakeUp() : void{
		m_flags &= ~e_sleepFlag;
		m_sleepTime = 0.0;
	}

	/**
	* Put this body to sleep so it will stop simulating.
	* This also sets the velocity to zero.
	*/
	public function PutToSleep() : void
	{
		m_flags |= e_sleepFlag;
		m_sleepTime = 0.0;
		m_linearVelocity.SetZero();
		m_angularVelocity = 0.0;
		m_force.SetZero();
		m_torque = 0.0;
	}

	/**
	* Get the list of all fixtures attached to this body.
	*/
	public function GetFixtureList() : b2Fixture{
		return m_fixtureList;
	}

	/**
	* Get the list of all joints attached to this body.
	*/
	public function GetJointList() : b2JointEdge{
		return m_jointList;
	}
	
	/**
	 * Get the list of all controllers attached to this body.
	 */
	public function GetControllerList() : b2ControllerEdge {
		return m_controllerList;
	}
	
	public function GetContactList():b2ContactEdge {
		return m_contactList;
	}

	/**
	* Get the next body in the world's body list.
	*/
	public function GetNext() : b2Body{
		return m_next;
	}

	/**
	* Get the user data pointer that was provided in the body definition.
	*/
	public function GetUserData() : *{
		return m_userData;
	}

	/**
	* Set the user data. Use this to store your application specific data.
	*/
	public function SetUserData(data:*) : void
	{
		m_userData = data;
	}

	/**
	* Get the parent world of this body.
	*/
	public function GetWorld(): b2World
	{
		return m_world;
	}

	//--------------- Internals Below -------------------

	
	// Constructor
	/**
	 * @private
	 */
	public function b2Body(bd:b2BodyDef, world:b2World){
		//b2Settings.b2Assert(world.IsLocked() == false);
		
		m_flags = 0;
		
		if (bd.isBullet)
		{
			m_flags |= e_bulletFlag;
		}
		if (bd.fixedRotation)
		{
			m_flags |= e_fixedRotationFlag;
		}
		if (bd.allowSleep)
		{
			m_flags |= e_allowSleepFlag;
		}
		if (bd.isSleeping)
		{
			m_flags |= e_sleepFlag;
		}
		
		m_world = world;
		
		m_xf.position.SetV(bd.position);
		m_xf.R.Set(bd.angle);
		
		m_sweep.localCenter.SetV(bd.massData.center);
		m_sweep.t0 = 1.0;
		m_sweep.a0 = m_sweep.a = bd.angle;
		
		//m_sweep.c0 = m_sweep.c = b2Mul(m_xf, m_sweep.localCenter);
		//b2MulMV(m_xf.R, m_sweep.localCenter);
		var tMat:b2Mat22 = m_xf.R;
		var tVec:b2Vec2 = m_sweep.localCenter;
		// (tMat.col1.x * tVec.x + tMat.col2.x * tVec.y)
		m_sweep.c.x = (tMat.col1.x * tVec.x + tMat.col2.x * tVec.y);
		// (tMat.col1.y * tVec.x + tMat.col2.y * tVec.y)
		m_sweep.c.y = (tMat.col1.y * tVec.x + tMat.col2.y * tVec.y);
		//return T.position + b2Mul(T.R, v);
		m_sweep.c.x += m_xf.position.x;
		m_sweep.c.y += m_xf.position.y;
		//m_sweep.c0 = m_sweep.c
		m_sweep.c0.SetV(m_sweep.c);
		
		m_jointList = null;
		m_controllerList = null;
		m_contactList = null;
		m_controllerCount = 0;
		m_prev = null;
		m_next = null;
		
		m_linearVelocity.SetV(bd.linearVelocity);
		m_angularVelocity = bd.angularVelocity;
		
		m_linearDamping = bd.linearDamping;
		m_angularDamping = bd.angularDamping;
		
		m_force.Set(0.0, 0.0);
		m_torque = 0.0;
		
		m_sleepTime = 0.0;
		
		m_invMass = 0.0;
		m_I = 0.0;
		m_invI = 0.0;
		
		m_mass = bd.massData.mass;
		
		if (m_mass > 0.0)
		{
			m_invMass = 1.0 / m_mass;
		}
		
		if ((m_flags & b2Body.e_fixedRotationFlag) == 0)
		{
			m_I = bd.massData.I;
		}
		
		if (m_I > 0.0)
		{
			m_invI = 1.0 / m_I;
		}
		
		if (m_invMass == 0.0 && m_invI == 0.0)
		{
			m_type = e_staticType;
		}
		else
		{
			m_type = e_dynamicType;
		}
	
		m_userData = bd.userData;
		
		m_fixtureList = null;
		m_fixtureCount = 0;
	}
	
	// Destructor
	//~b2Body();

	//
	static private var s_xf1:b2Transform = new b2Transform();
	//
	b2internal function SynchronizeFixtures() : void{
		
		var xf1:b2Transform = s_xf1;
		xf1.R.Set(m_sweep.a0);
		//xf1.position = m_sweep.c0 - b2Mul(xf1.R, m_sweep.localCenter);
		var tMat:b2Mat22 = xf1.R;
		var tVec:b2Vec2 = m_sweep.localCenter;
		xf1.position.x = m_sweep.c0.x - (tMat.col1.x * tVec.x + tMat.col2.x * tVec.y);
		xf1.position.y = m_sweep.c0.y - (tMat.col1.y * tVec.x + tMat.col2.y * tVec.y);
		
		var f:b2Fixture;
		var broadPhase:IBroadPhase = m_world.m_contactManager.m_broadPhase;
		for (f = m_fixtureList; f; f = f.m_next)
		{
			f.Synchronize(broadPhase, xf1, m_xf);
		}
	}

	b2internal function SynchronizeTransform() : void{
		m_xf.R.Set(m_sweep.a);
		//m_xf.position = m_sweep.c - b2Mul(m_xf.R, m_sweep.localCenter);
		var tMat:b2Mat22 = m_xf.R;
		var tVec:b2Vec2 = m_sweep.localCenter;
		m_xf.position.x = m_sweep.c.x - (tMat.col1.x * tVec.x + tMat.col2.x * tVec.y);
		m_xf.position.y = m_sweep.c.y - (tMat.col1.y * tVec.x + tMat.col2.y * tVec.y);
	}

	// This is used to prevent connected bodies from colliding.
	// It may lie, depending on the collideConnected flag.
	b2internal function IsConnected(other:b2Body) : Boolean{
		for (var jn:b2JointEdge = m_jointList; jn; jn = jn.next)
		{
			if (jn.other == other)
				return jn.joint.m_collideConnected == false;
		}
		
		return false;
	}

	b2internal function Advance(t:Number) : void{
		// Advance to the new safe time.
		m_sweep.Advance(t);
		m_sweep.c.SetV(m_sweep.c0);
		m_sweep.a = m_sweep.a0;
		SynchronizeTransform();
	}

	b2internal var m_flags:uint;
	private var m_type:int;
	
	b2internal var m_islandIndex:int;

	b2internal var m_xf:b2Transform = new b2Transform();		// the body origin transform

	b2internal var m_sweep:b2Sweep = new b2Sweep();	// the swept motion for CCD

	b2internal var m_linearVelocity:b2Vec2 = new b2Vec2();
	b2internal var m_angularVelocity:Number;

	b2internal var m_force:b2Vec2 = new b2Vec2();
	b2internal var m_torque:Number;

	b2internal var m_world:b2World;
	b2internal var m_prev:b2Body;
	b2internal var m_next:b2Body;

	b2internal var m_fixtureList:b2Fixture;
	b2internal var m_fixtureCount:int;
	
	b2internal var m_controllerList:b2ControllerEdge;
	b2internal var m_controllerCount:int;

	b2internal var m_jointList:b2JointEdge;
	b2internal var m_contactList:b2ContactEdge;

	b2internal var m_mass:Number, m_invMass:Number;
	b2internal var m_I:Number, m_invI:Number;

	b2internal var m_linearDamping:Number;
	b2internal var m_angularDamping:Number;

	b2internal var m_sleepTime:Number;

	private var m_userData:*;
	
	
	// m_flags
	//enum
	//{
		static b2internal var e_islandFlag:uint			= 0x0001;
		static b2internal var e_sleepFlag:uint			= 0x0002;
		static b2internal var e_allowSleepFlag:uint		= 0x0004;
		static b2internal var e_bulletFlag:uint			= 0x0005;
		static b2internal var e_fixedRotationFlag:uint	= 0x0010;
	//};

	// m_type
	//enum
	//{
		static b2internal var e_staticType:uint 	= 1;
		static b2internal var e_dynamicType:uint 	= 2;
		static b2internal var e_maxTypes:uint 		= 3;
	//};
	
};

}
